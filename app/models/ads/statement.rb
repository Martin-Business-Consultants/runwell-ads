module Ads
  # One month's figure for one ad service: the spend LuminAds reports (up to through_on), the fee
  # terms used (copied, so a later change to them doesn't rewrite a settled month), the fee it comes
  # to and why (the minimum, a flat fee or the share of spend), and, while invoicing is on, the
  # QuickBooks invoice drafted from it.
  #
  # States (STATES): running while the month is open or still settling (refreshed nightly and on
  # request, so the cost is always current); final once its run day has come (Setting#final?); then,
  # only while invoicing is on, invoiced (a draft in QuickBooks, unsent) or skipped (not billed;
  # restore puts it back). Each move is a verb that refuses what the state doesn't allow (Refused),
  # with the predicate pages and tools ask first. Settled months record an event on the work; the
  # nightly refresh of an open month doesn't.
  class Statement < ::ApplicationRecord
    self.table_name = "ads_statements"

    STATES = %w[running final invoiced skipped].freeze

    class Refused < StandardError; end

    belongs_to :plan, class_name: "Ads::Plan"
    belongs_to :work
    belongs_to :client
    belongs_to :task, optional: true
    belongs_to :invoiced_by, class_name: "User", optional: true
    belongs_to :skipped_by, class_name: "User", optional: true

    validates :state, inclusion: { in: STATES }
    validates :rule, inclusion: { in: Terms::RULES.keys }

    scope :ordered, -> { order(period_on: :desc, id: :desc) }
    scope :in_period, ->(period) { where(period_on: period) }

    # A month read (again) for a plan: spend from LuminAds up to today (or the month's end), the fee
    # from the plan's terms. Final once the month has settled; then, while invoicing is on, its draft
    # in QuickBooks and a task to review it. Run from jobs: LuminAds and QuickBooks are other
    # services, never waited on in a request.
    def self.run!(plan, period, setting: Setting.current)
      statement = refresh!(plan, period, setting: setting)
      if statement.final? && setting.invoicing
        if statement.invoiceable? && statement.invoice_blocker.nil?
          begin
            statement.draft_invoice!
          rescue QuickbooksApi::Error
            nil # kept on the statement; the review task still opens
          end
        end
        statement.open_review_task!(setting)
      end
      plan.update_columns(last_error: nil, updated_at: Time.current)
      statement
    rescue Luminads::Error => e
      plan.update_columns(last_error: e.message.truncate(500), updated_at: Time.current)
      raise
    end

    def self.refresh!(plan, period, setting: Setting.current)
      period = period.to_date.beginning_of_month
      statement = plan.statements.find_or_initialize_by(period_on: period)
      raise Refused, "#{period.strftime("%B %Y")} for #{plan.work.title} is #{statement.state}: it’s settled" if statement.persisted? && !statement.refreshable?
      raise Luminads::Error, setting.luminads_blocker if setting.luminads_blocker
      raise Luminads::Error, "#{plan.work.title} has no LuminAds account linked" if plan.account_ids.empty?

      through = [ Date.current, period.end_of_month ].min
      spend = Luminads.new(setting).spend(plan.luminads_accounts, period..through)
      terms = plan.terms(setting)
      fee, basis = terms.fee_for(spend.total_cents)
      final = setting.final?(period)
      statement.update!(work: plan.work, client: plan.client, through_on: through, state: final ? "final" : "running",
        spend_cents: spend.total_cents, spend_detail: spend.detail, rule: terms.rule, minimum_cents: terms.minimum_cents,
        percent: terms.percent, fee_cents: fee, basis: basis, refreshed_at: Time.current, last_error: nil)
      statement.work.record_event!("ads.month_final", actor: nil, source: "app", actor_label: "Ads", payload: statement.event_payload) if final
      statement
    end

    def running? = state == "running"
    def final? = state == "final"
    def invoiced? = state == "invoiced"
    def skipped? = state == "skipped"
    # Asked for, not back from QuickBooks yet.
    def invoicing? = final? && invoice_requested_at.present?

    def refreshable? = running? || (final? && !invoicing?)
    def invoiceable? = final? && !invoicing? && fee_cents.positive? && Setting.current.invoicing
    def skippable? = final? && !invoicing? && Setting.current.invoicing
    def restorable? = skipped?

    def terms = Terms.new(rule: rule, minimum_cents: minimum_cents, percent: percent)
    def period_name = period_on.strftime("%B %Y")
    def basis_name = Terms::BASES[basis]
    def invoice_blocker = Setting.current.invoice_blocker || (plan.quickbooks_customer_id.blank? ? "no QuickBooks customer is chosen for #{work.title}" : nil)

    # How many days of the month the spend covers, and what the month comes to at that pace.
    def days_counted = (through_on - period_on).to_i + 1
    def days_in_month = period_on.end_of_month.day
    def partial? = running? && days_counted < days_in_month

    def projected_spend_cents
      partial? ? (BigDecimal(spend_cents) / days_counted * days_in_month).round : spend_cents
    end

    def projected_fee_cents = partial? ? terms.fee_for(projected_spend_cents).first : fee_cents

    # Asks for the draft; InvoiceJob makes it.
    def request_invoice!(by:)
      raise Refused, refusal("drafted") unless invoiceable?
      raise Refused, "Can’t draft the invoice: #{invoice_blocker}." if invoice_blocker

      update!(invoice_requested_at: Time.current, invoiced_by: by, last_error: nil)
      InvoiceJob.perform_later(self)
    end

    # The draft itself, unsent, in QuickBooks. Safe to retry: a statement with an invoice makes no
    # second one, and QuickBooks drops a repeat of the same request.
    def draft_invoice!
      return self if invoice_qbo_id.present?
      if (blocker = invoice_blocker)
        update!(invoice_requested_at: nil, last_error: "Can’t draft the invoice: #{blocker}.")
        raise Refused, last_error
      end

      setting = Setting.current
      invoice = QuickbooksApi.new.create_invoice(invoice_payload(setting), request_id: "ads-#{id}-#{(invoice_requested_at || refreshed_at).to_i}")
      update!(state: "invoiced", invoice_qbo_id: invoice["Id"], invoice_doc_number: invoice["DocNumber"], invoiced_at: Time.current,
        invoice_requested_at: nil, last_error: nil)
      work.record_event!("ads.invoiced", actor: invoiced_by, source: "app", actor_label: "Ads",
        payload: event_payload.merge(invoice: invoice_doc_number || invoice_qbo_id))
      refresh_review_task!
      self
    rescue QuickbooksApi::Error => e
      update!(invoice_requested_at: nil, last_error: e.message.truncate(500))
      raise
    end

    def skip!(by:, reason: nil)
      raise Refused, refusal("skipped") unless skippable?

      update!(state: "skipped", skipped_at: Time.current, skipped_by: by, skip_reason: reason.presence)
      work.record_event!("ads.skipped", payload: event_payload.merge(reason: skip_reason))
    end

    def restore!(by:)
      raise Refused, "#{period_name} for #{work.title} isn’t skipped" unless restorable?

      update!(state: "final", skipped_at: nil, skipped_by: nil, skip_reason: nil)
      work.record_event!("ads.restored", payload: event_payload)
    end

    # Someone to check the draft and send it, on the work: whoever reviews, else Intake.
    def open_review_task!(setting = Setting.current)
      return task if task

      created = work.tasks.create!(title: review_title, description: review_description, owner: plan.review_by(setting), source: "app")
      update!(task: created)
      created
    end

    def refresh_review_task!
      task.update!(title: review_title, description: review_description) if task && task.status != "done"
    end

    def event_payload
      { period: period_on.iso8601, spend_cents: spend_cents, fee_cents: fee_cents, basis: basis, terms: terms.to_s }
    end

    # The spend, the terms, and how they came to the fee, in a sentence.
    def explanation
      share = terms.share_of(spend_cents)
      percent = Terms.percent_label(self.percent)
      case basis
      when "flat" then "A flat fee of #{Money.format(fee_cents)}."
      when "percent"
        rule == "percent" ? "#{percent} of #{Money.format(spend_cents)} is #{Money.format(share)}." :
          "#{percent} of #{Money.format(spend_cents)} is #{Money.format(share)}, more than the #{Money.format(minimum_cents)} minimum."
      else "#{percent} of #{Money.format(spend_cents)} is #{Money.format(share)}, under the #{Money.format(minimum_cents)} minimum, so the minimum applies."
      end
    end

    private
      def refusal(verb)
        return "invoicing is off (Settings › Plugins › Ads)" unless Setting.current.invoicing
        return "#{period_name} for #{work.title} is still open: it’s final on its run day" if running?
        return "#{period_name} for #{work.title} is already invoiced" if invoiced?
        return "#{period_name} for #{work.title} is skipped" if skipped?
        return "#{period_name} for #{work.title} is being drafted in QuickBooks now" if invoicing?
        return "#{period_name} for #{work.title} comes to nothing, so there’s nothing to invoice" if fee_cents.zero?

        "#{period_name} for #{work.title} can’t be #{verb}"
      end

      def review_title
        "#{invoiced? ? "Send" : "Review"} the #{period_on.strftime("%B")} ad fee for #{work.title}: #{Money.format(fee_cents)}"
      end

      def review_description
        accounts = Array(spend_detail).map { "#{ERB::Util.h(it["name"])} #{Money.format(it["cents"])}" }.join(", ")
        lines = [
          "<p>Ad spend in #{period_name}: <strong>#{Money.format(spend_cents)}</strong>#{" (#{accounts})" if accounts.present?}.</p>",
          "<p>Terms: #{ERB::Util.h(terms.to_s)}. #{ERB::Util.h(explanation)} The fee is <strong>#{Money.format(fee_cents)}</strong>.</p>"
        ]
        lines << if invoiced?
          "<p>Invoice #{ERB::Util.h(invoice_doc_number || invoice_qbo_id)} is drafted in QuickBooks, not sent. Check it there and send it, then mark this done.</p>"
        else
          "<p>No invoice yet. If the numbers are right, draft it from the Ads tab on this work; QuickBooks keeps it unsent until you send it.</p>"
        end
        lines.join
      end

      def invoice_payload(setting)
        description = "Ad management, #{period_name}: #{terms}. Ad spend #{Money.format(spend_cents)}. #{explanation}"
        amount = (BigDecimal(fee_cents) / 100).to_f
        {
          "CustomerRef" => { "value" => plan.quickbooks_customer_id },
          "TxnDate" => Date.current.iso8601,
          "Line" => [ {
            "DetailType" => "SalesItemLineDetail", "Amount" => amount, "Description" => description.truncate(4000),
            "SalesItemLineDetail" => { "ItemRef" => { "value" => setting.quickbooks_item_id }, "Qty" => 1, "UnitPrice" => amount }
          } ],
          "PrivateNote" => "Runwell ad fee: #{work.ref}, #{period_name}",
          "EmailStatus" => "NotSet"
        }
      end
  end
end

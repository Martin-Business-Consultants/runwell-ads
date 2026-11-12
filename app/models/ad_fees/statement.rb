module AdFees
  # One month's ad fee for one plan: the spend LuminAds reported, the terms used (copied, so a later
  # change to them doesn't rewrite history), the fee and why (the minimum, a flat fee or the share
  # of spend), and the QuickBooks invoice drafted from it.
  #
  # States (STATES): calculated, then invoiced once its draft is in QuickBooks, or skipped (not billed
  # this month; restore puts it back). Each move is a verb that refuses what the state doesn't allow
  # (Refused), with the predicate the pages and tools ask first, and records an event on the work.
  # Invoices are drafts: created unsent, for someone to check and send from QuickBooks.
  class Statement < ::ApplicationRecord
    self.table_name = "ad_fees_statements"

    STATES = %w[calculated invoiced skipped].freeze

    class Refused < StandardError; end

    belongs_to :plan, class_name: "AdFees::Plan"
    belongs_to :work
    belongs_to :client
    belongs_to :task, optional: true
    belongs_to :invoiced_by, class_name: "User", optional: true
    belongs_to :skipped_by, class_name: "User", optional: true

    validates :state, inclusion: { in: STATES }
    validates :rule, inclusion: { in: Terms::RULES.keys }

    scope :ordered, -> { order(period_on: :desc, id: :desc) }
    scope :in_period, ->(period) { where(period_on: period) }

    # Last month, worked out (or worked out again) for a plan: spend read from LuminAds, the fee
    # from the plan's terms, then, if the install drafts invoices and nothing stands in the way,
    # the QuickBooks draft, and a task for someone to review it. Run from jobs: LuminAds and
    # QuickBooks are other services, never waited on in a request.
    def self.run!(plan, period, setting: Setting.current)
      statement = calculate!(plan, period, setting: setting)
      if setting.draft_invoices && statement.invoiceable? && statement.invoice_blocker.nil?
        # A draft that fails keeps its error on the statement; the review task still opens.
        begin
          statement.draft_invoice!
        rescue QuickbooksApi::Error
          nil
        end
      end
      statement.open_review_task!(setting)
      plan.update_columns(last_error: nil, updated_at: Time.current)
      statement
    rescue Luminads::Error => e
      plan.update_columns(last_error: e.message.truncate(500), updated_at: Time.current)
      raise
    end

    def self.calculate!(plan, period, setting: Setting.current)
      period = period.to_date.beginning_of_month
      statement = plan.statements.find_or_initialize_by(period_on: period)
      raise Refused, "#{period.strftime("%B %Y")} for #{plan.work.title} is #{statement.state}: it can’t be worked out again" if statement.persisted? && !statement.recalculable?
      raise Luminads::Error, setting.luminads_blocker if setting.luminads_blocker
      raise Luminads::Error, "#{plan.work.title} has no LuminAds account linked" if plan.account_ids.empty?

      spend = Luminads.new(setting).spend(plan.luminads_accounts, period..period.end_of_month)
      terms = plan.terms(setting)
      fee, basis = terms.fee_for(spend.total_cents)
      recalculated = statement.persisted?
      statement.update!(work: plan.work, client: plan.client, spend_cents: spend.total_cents, spend_detail: spend.detail,
        rule: terms.rule, minimum_cents: terms.minimum_cents, percent: terms.percent, fee_cents: fee, basis: basis,
        calculated_at: Time.current, last_error: nil)
      statement.work.record_event!(recalculated ? "ad_fees.recalculated" : "ad_fees.calculated", actor: nil, source: "app",
        actor_label: "Ad fees", payload: statement.event_payload)
      statement.refresh_review_task! if recalculated
      statement
    end

    def calculated? = state == "calculated"
    def invoiced? = state == "invoiced"
    def skipped? = state == "skipped"
    # Asked for, not back from QuickBooks yet.
    def invoicing? = calculated? && invoice_requested_at.present?

    def invoiceable? = calculated? && !invoicing? && fee_cents.positive?
    def recalculable? = calculated? && !invoicing?
    def skippable? = calculated? && !invoicing?
    def restorable? = skipped?

    def terms = Terms.new(rule: rule, minimum_cents: minimum_cents, percent: percent)
    def period_name = period_on.strftime("%B %Y")
    def basis_name = Terms::BASES[basis]
    def invoice_blocker = Setting.current.invoice_blocker || (plan.quickbooks_customer_id.blank? ? "no QuickBooks customer is chosen for #{work.title}" : nil)

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
      invoice = QuickbooksApi.new.create_invoice(invoice_payload(setting), request_id: "ad-fees-#{id}-#{(invoice_requested_at || calculated_at).to_i}")
      update!(state: "invoiced", invoice_qbo_id: invoice["Id"], invoice_doc_number: invoice["DocNumber"], invoiced_at: Time.current,
        invoice_requested_at: nil, last_error: nil)
      work.record_event!("ad_fees.invoiced", actor: invoiced_by, source: "app", actor_label: "Ad fees",
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
      work.record_event!("ad_fees.skipped", payload: event_payload.merge(reason: skip_reason))
    end

    def restore!(by:)
      raise Refused, "#{period_name} for #{work.title} isn’t skipped" unless restorable?

      update!(state: "calculated", skipped_at: nil, skipped_by: nil, skip_reason: nil)
      work.record_event!("ad_fees.restored", payload: event_payload)
    end

    # Someone to check the draft and send it, on the work: whoever reviews ad fees, else Intake.
    def open_review_task!(setting = Setting.current)
      return task if task

      reviewer = plan.review_by(setting)
      created = work.tasks.create!(title: review_title, description: review_description, owner: reviewer, source: "app")
      update!(task: created)
      created
    end

    def refresh_review_task!
      task.update!(title: review_title, description: review_description) if task && task.status != "done"
    end

    def event_payload
      { period: period_on.iso8601, spend_cents: spend_cents, fee_cents: fee_cents, basis: basis, terms: terms.to_s }
    end

    # Spend, the terms, and how they came to the fee, in a sentence or two.
    def explanation
      share = terms.share_of(spend_cents)
      case basis
      when "flat" then "A flat fee of #{Money.format(fee_cents)}."
      when "percent"
        rule == "percent" ? "#{Terms.percent_label(percent)} of #{Money.format(spend_cents)} is #{Money.format(share)}." :
          "#{Terms.percent_label(percent)} of #{Money.format(spend_cents)} is #{Money.format(share)}, more than the #{Money.format(minimum_cents)} minimum."
      else "#{Terms.percent_label(percent)} of #{Money.format(spend_cents)} is #{Money.format(share)}, under the #{Money.format(minimum_cents)} minimum, so the minimum applies."
      end
    end

    private
      def refusal(verb)
        return "#{period_name} for #{work.title} is already invoiced" if invoiced?
        return "#{period_name} for #{work.title} is skipped" if skipped?
        return "#{period_name} for #{work.title} is being drafted in QuickBooks now" if invoicing?
        return "#{period_name} for #{work.title} comes to nothing, so there’s nothing to invoice" if fee_cents.zero?

        "#{period_name} for #{work.title} can’t be #{verb}"
      end

      def review_title
        verb = invoiced? ? "Send" : "Review"
        "#{verb} the #{period_on.strftime("%B")} ad fee for #{work.title}: #{Money.format(fee_cents)}"
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
          "<p>No invoice yet. If the numbers are right, draft it from the Ad fees tab on this work; QuickBooks keeps it unsent until you send it.</p>"
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

module AdFees
  # A piece of work's ad fee: which LuminAds accounts are its spend, which QuickBooks customer is
  # billed, and its terms. Blank terms follow the install's defaults (whichever is greater of the
  # minimum and the share of spend); a plan sets its own rule, minimum or share to override them.
  # Any kind of work may have one: a service billed monthly, a project or a work order.
  #
  # The first month billed is starts_on's; a plan switched off is billed no more, its statements kept.
  class Plan < ::ApplicationRecord
    self.table_name = "ad_fees_plans"

    belongs_to :work
    belongs_to :client
    belongs_to :reviewer, class_name: "User", optional: true
    has_many :statements, class_name: "AdFees::Statement", dependent: :destroy

    before_validation { self.client_id = work&.client_id }
    before_validation { self.starts_on ||= Date.current.beginning_of_month }

    validates :work_id, uniqueness: true
    validates :rule, inclusion: { in: Terms::RULES.keys }, allow_nil: true
    validates :minimum_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true
    validates :percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

    normalizes :rule, with: -> { it.presence }
    normalizes :quickbooks_customer_id, with: -> { it.presence }

    scope :active, -> { where(active: true) }
    # Plans with a month to bill for period (the first of a month).
    scope :billable_in, ->(period) { active.where(starts_on: ..period.end_of_month) }

    # The terms this work is billed on: its own where it has them, the install's elsewhere.
    def terms(setting = Setting.current)
      Terms.new(rule: rule || setting.default_rule,
        minimum_cents: minimum_cents.nil? ? setting.default_minimum_cents : minimum_cents,
        percent: percent.nil? ? setting.default_percent : percent)
    end

    def own_terms? = rule.present? || !minimum_cents.nil? || !percent.nil?

    # [{ "id" => 12, "name" => "Bloom (Google Ads)" }], names kept for showing without asking LuminAds.
    def account_ids = Array(luminads_accounts).map { it["id"] }
    def account_names = Array(luminads_accounts).map { it["name"] }
    # What the form's account picker reads.
    def luminads_account_ids = account_ids

    def review_by(setting = Setting.current) = reviewer || setting.reviewer

    # Why this work's fee can't be worked out or drafted, in words, or nil.
    def blocker
      return "no LuminAds account is linked" if account_ids.empty?
      return "no QuickBooks customer is chosen" if quickbooks_customer_id.blank?

      nil
    end
  end
end

module Ads
  # A piece of work tagged as an ad service (KINDS: PPC for now), from its Ads tab: which LuminAds
  # accounts are its spend, and its fee terms. Blank terms follow the install's defaults (whichever
  # is greater of the minimum and the share of spend); a plan sets its own rule, minimum or share
  # to override them. Any kind of work may be tagged: a service, a project or a work order.
  #
  # Paused (active false), its figures stop; its months are kept. The QuickBooks customer and
  # reviewer matter only while invoicing is on.
  class Plan < ::ApplicationRecord
    self.table_name = "ads_plans"

    KINDS = { "ppc" => "PPC" }.freeze

    belongs_to :work
    belongs_to :client
    belongs_to :reviewer, class_name: "User", optional: true
    has_many :statements, class_name: "Ads::Statement", dependent: :destroy

    before_validation { self.client_id = work&.client_id }
    before_validation { self.starts_on ||= Date.current.beginning_of_month }

    validates :work_id, uniqueness: true
    validates :kind, inclusion: { in: KINDS.keys }
    validates :rule, inclusion: { in: Terms::RULES.keys }, allow_nil: true
    validates :minimum_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true
    validates :percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

    normalizes :rule, with: -> { it.presence }
    normalizes :quickbooks_customer_id, with: -> { it.presence }

    scope :active, -> { where(active: true) }
    # Plans counted in period (the first of a month).
    scope :live_in, ->(period) { active.where(starts_on: ..period.end_of_month) }

    def kind_name = KINDS[kind]

    # The terms this work's fee is on: its own where it has them, the install's elsewhere.
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

    # This month's figure, if it's been read.
    def current_statement = statements.find_by(period_on: Date.current.beginning_of_month)

    # Why this work's figure can't be read (or, while invoicing is on, drafted), in words, or nil.
    def blocker(setting = Setting.current)
      return "no LuminAds account is linked" if account_ids.empty?
      return "no QuickBooks customer is chosen" if setting.invoicing && quickbooks_customer_id.blank?

      nil
    end
  end
end

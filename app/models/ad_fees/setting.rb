module AdFees
  # The install's ad fee settings (one row): where LuminAds is and the token it reads spend with,
  # the default terms, the day of the month last month's fees are worked out, whether that run
  # drafts the QuickBooks invoices straight away, who reviews them, and the QuickBooks product or
  # service the invoice line uses.
  class Setting < ::ApplicationRecord
    self.table_name = "ad_fees_settings"

    # A LuminAds token reads every ad account it can see.
    encrypts :luminads_token

    belongs_to :reviewer, class_name: "User", optional: true

    validates :default_rule, inclusion: { in: Terms::RULES.keys }
    validates :default_minimum_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
    validates :default_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
    # Up to the 28th, so every month has the day.
    validates :run_on_day, numericality: { in: 1..28, only_integer: true }
    validates :luminads_url, format: { with: %r{\Ahttps?://[^\s/]+[^\s]*\z}, message: "must be an address starting with https://" }, allow_blank: true

    before_validation { self.luminads_url = luminads_url.to_s.strip.delete_suffix("/").presence }

    def self.current = first || create!

    def terms = Terms.new(rule: default_rule, minimum_cents: default_minimum_cents, percent: default_percent)
    def luminads_ready? = luminads_url.present? && luminads_token.present?

    # Why fees can't be worked out, in words, or nil when they can.
    def luminads_blocker
      return "LuminAds isn’t connected: give its address and a token in Settings › Plugins › Ad fees" unless luminads_ready?

      nil
    end

    # Why an invoice can't be drafted, in words, or nil when it can.
    def invoice_blocker
      connection = QuickbooksConnection.current
      return "QuickBooks isn’t connected: sign in from Settings › Plugins › Ad fees" unless connection&.connected?
      return "QuickBooks needs reconnecting: the sign-in has expired" if connection.refresh_expired?
      return "no QuickBooks product or service is chosen for the invoice line" if quickbooks_item_id.blank?

      nil
    end
  end
end

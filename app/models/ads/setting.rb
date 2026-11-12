module Ads
  # The install's Ads settings (one row): where LuminAds is and the token it reads spend with, the
  # default fee terms, the day of the month last month's figure becomes final, and invoicing, off
  # until someone switches it on: who reviews each draft and the QuickBooks product on its line.
  class Setting < ::ApplicationRecord
    self.table_name = "ads_settings"

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

    # Why spend can't be read, in words, or nil when it can.
    def luminads_blocker
      return "LuminAds isn’t connected: give its address and a token in Settings › Plugins › Ads" unless luminads_ready?

      nil
    end

    # Why an invoice can't be drafted, in words, or nil when it can.
    def invoice_blocker
      return "invoicing is off (Settings › Plugins › Ads)" unless invoicing

      connection = QuickbooksConnection.current
      return "QuickBooks isn’t connected: sign in from Settings › Plugins › Ads" unless connection&.connected?
      return "QuickBooks needs reconnecting: the sign-in has expired" if connection.refresh_expired?
      return "no QuickBooks product or service is chosen for the invoice line" if quickbooks_item_id.blank?

      nil
    end

    # Whether a month is settled: over, and its run day (in the month after) has come.
    def final?(period, today = Date.current)
      today >= period.next_month.beginning_of_month.change(day: run_on_day)
    end
  end
end

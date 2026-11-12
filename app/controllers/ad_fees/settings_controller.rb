module AdFees
  # Settings › Plugins › Ad fees: the default terms, the run day, whether the run drafts invoices,
  # who reviews them and the QuickBooks product or service on the line. The keys to LuminAds and
  # QuickBooks are on the same page but saved by ConnectionsController, in the browser only.
  class SettingsController < ApplicationController
    allow_staff
    require_permission :manage_settings
    agent_tool :show_ad_fee_settings, on: :show, title: "Show the ad fee settings",
      description: "The default terms (rule, minimum, share of spend), the day of the month last month's fees are worked out, whether that drafts the QuickBooks invoices, who reviews them, the QuickBooks product or service on the invoice line, and whether LuminAds and QuickBooks are connected."
    agent_tool :update_ad_fee_settings, on: :update, title: "Change the default ad fee terms",
      description: "default_rule: greater_of (the minimum or the share of spend, whichever is greater), flat (the minimum only) or percent (the share only). default_minimum_cents: whole cents (100000 is $1,000). default_percent: the share of spend, 20 for 20%. run_on_day: 1 to 28, the day last month's fees are worked out. draft_invoices: draft each in QuickBooks, unsent, as it's worked out. reviewer_id: who gets the review task (blank: Intake). quickbooks_item_id: the QuickBooks product or service on the line (show_ad_fee_settings lists them). A plan's own terms override these.",
      params: { setting: { default_rule: Terms::RULES.keys, default_minimum_cents: "integer", default_percent: "number", run_on_day: "integer",
        draft_invoices: "boolean", reviewer_id: "integer", quickbooks_item_id: "string" } },
      next_tools: %i[show_ad_fee_settings]

    before_action { @setting = Setting.current }

    def show
      @connection = QuickbooksConnection.for_settings
      @items = @connection.connected? ? Directory.quickbooks_items : Directory::Listing.new(items: [], error: nil)
    end

    def update
      attributes = params.expect(setting: %i[default_rule default_minimum_cents default_percent run_on_day draft_invoices reviewer_id quickbooks_item_id])
      if attributes.key?(:quickbooks_item_id)
        attributes[:quickbooks_item_name] = Directory.quickbooks_items.items.find { it["id"] == attributes[:quickbooks_item_id] }&.dig("name")
      end
      if @setting.update(attributes)
        redirect_to ad_fees_settings_path, notice: "Saved. New fees are #{@setting.terms}, unless a #{helpers.term(:work).downcase} has terms of its own."
      else
        redirect_to ad_fees_settings_path, alert: @setting.errors.full_messages.to_sentence
      end
    end
  end
end

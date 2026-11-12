module AdFees
  # What a plan can be set to, for agents: LuminAds' ad accounts and QuickBooks' customers (and the
  # product or service lines may use), with why either list is empty.
  class ChoicesController < ApplicationController
    allow_staff
    require_permission :manage_ad_fees
    agent_tool :list_ad_fee_choices, on: :show, title: "List the LuminAds accounts and QuickBooks customers a plan can use",
      description: "The ids set_ad_fee_plan takes: luminads_account_ids from accounts, quickbooks_customer_id from customers."

    def show
      @accounts = Directory.luminads_accounts
      @customers = QuickbooksConnection.current&.connected? ? Directory.quickbooks_customers : Directory::Listing.new(items: [], error: Setting.current.invoice_blocker)
      respond_to do |format|
        format.html { redirect_to ad_fees_statements_path }
        format.json
      end
    end
  end
end

module Ads
  # What a plan can be set to, for agents: LuminAds' ad accounts and QuickBooks' customers (and the
  # product or service lines may use), with why either list is empty.
  class ChoicesController < ApplicationController
    allow_staff
    require_permission :manage_ads
    agent_tool :list_ads_choices, on: :show, title: "List the LuminAds accounts and QuickBooks customers a plan can use",
      description: "The ids tag_ppc_service takes: luminads_account_ids from accounts, quickbooks_customer_id from customers."

    def show
      @accounts = Directory.luminads_accounts
      @customers = QuickbooksConnection.current&.connected? ? Directory.quickbooks_customers : Directory::Listing.new(items: [], error: Setting.current.invoice_blocker)
      respond_to do |format|
        format.html { redirect_to ads_statements_path }
        format.json
      end
    end
  end
end

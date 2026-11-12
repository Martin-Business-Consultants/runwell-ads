module Ads
  module Statements
    # Drafts a settled month's invoice in QuickBooks, unsent, in the background (InvoiceJob). Only
    # while invoicing is on (Settings › Plugins › Ads).
    class InvoicesController < ApplicationController
      allow_staff
      require_permission :manage_ads
      agent_tool :draft_ad_invoice, on: :create, title: "Draft a month's ad fee invoice in QuickBooks",
        description: "statement_id: from list_ad_costs or show_ppc_service. Only while invoicing is on, and only for a final month. Creates the invoice in QuickBooks, unsent: someone checks and sends it there.",
        next_tools: %i[list_ad_costs]

      before_action :set_statement

      def create
        @statement.request_invoice!(by: Current.user)
        redirect_back fallback_location: work_tab_path(@statement.work),
          notice: "Drafting the #{@statement.period_name} invoice for #{@statement.work.title} (#{Money.format(@statement.fee_cents)}) in QuickBooks. It stays unsent until someone sends it there."
      rescue Statement::Refused => e
        redirect_back fallback_location: work_tab_path(@statement.work), alert: e.message
      end
    end
  end
end

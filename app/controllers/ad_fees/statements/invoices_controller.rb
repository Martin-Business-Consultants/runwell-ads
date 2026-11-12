module AdFees
  module Statements
    # Drafts a month's invoice in QuickBooks, unsent: in the background (InvoiceJob), so the page
    # says it's on its way and shows the invoice a moment later.
    class InvoicesController < ApplicationController
      allow_staff
      require_permission :manage_ad_fees
      agent_tool :draft_ad_fee_invoice, on: :create, title: "Draft a month's ad fee invoice in QuickBooks",
        description: "statement_id: from list_ad_fee_statements or show_ad_fee_plan. Creates the invoice in QuickBooks, unsent: someone checks and sends it there. Refused once invoiced, while skipped, or while a draft is on its way.",
        next_tools: %i[list_ad_fee_statements]

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

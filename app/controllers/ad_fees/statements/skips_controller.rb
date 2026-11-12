module AdFees
  module Statements
    # Not billing a month (create, with an optional reason), or putting it back (destroy).
    class SkipsController < ApplicationController
      allow_staff
      require_permission :manage_ad_fees
      agent_tool :skip_ad_fee, on: :create, title: "Don't bill a month's ad fee",
        description: "statement_id; reason: why, kept on it. Refused once invoiced.", params: { reason: "string" },
        next_tools: %i[list_ad_fee_statements]
      agent_tool :restore_ad_fee, on: :destroy, title: "Bill a skipped month after all",
        description: "statement_id. Puts it back to calculated, to draft or work out again."

      before_action :set_statement

      def create
        @statement.skip!(by: Current.user, reason: params[:reason])
        redirect_back fallback_location: work_tab_path(@statement.work), notice: "#{@statement.period_name} for #{@statement.work.title} won’t be billed."
      rescue Statement::Refused => e
        redirect_back fallback_location: work_tab_path(@statement.work), alert: e.message
      end

      def destroy
        @statement.restore!(by: Current.user)
        redirect_back fallback_location: work_tab_path(@statement.work), notice: "#{@statement.period_name} for #{@statement.work.title} is back, ready to draft."
      rescue Statement::Refused => e
        redirect_back fallback_location: work_tab_path(@statement.work), alert: e.message
      end
    end
  end
end

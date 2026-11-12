module Ads
  module Statements
    # Not billing a settled month (create, with an optional reason), or putting it back (destroy).
    # Only while invoicing is on.
    class SkipsController < ApplicationController
      allow_staff
      require_permission :manage_ads
      agent_tool :skip_ad_month, on: :create, title: "Don't bill a month's ad fee",
        description: "statement_id; reason: why, kept on it. Only while invoicing is on, for a final month not yet invoiced.",
        params: { reason: "string" }, next_tools: %i[list_ad_costs]
      agent_tool :restore_ad_month, on: :destroy, title: "Bill a skipped month after all",
        description: "statement_id. Puts it back to final, ready to draft."

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

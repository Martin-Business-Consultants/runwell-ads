module AdFees
  module Statements
    # Works a month out again from LuminAds (spend settled late, or the terms changed), in the
    # background. Only before it's invoiced or skipped.
    class RecalculationsController < ApplicationController
      allow_staff
      require_permission :manage_ad_fees
      agent_tool :recalculate_ad_fee, on: :create, title: "Work a month's ad fee out again",
        description: "statement_id. Reads the month's spend from LuminAds again and applies the plan's current terms. Refused once invoiced or skipped.",
        next_tools: %i[list_ad_fee_statements]

      before_action :set_statement

      def create
        raise Statement::Refused, "#{@statement.period_name} for #{@statement.work.title} is #{@statement.invoicing? ? "being drafted in QuickBooks" : @statement.state}: it can’t be worked out again" unless @statement.recalculable?

        CalculateJob.perform_later(@statement.plan, @statement.period_on)
        redirect_back fallback_location: work_tab_path(@statement.work), notice: "Working out #{@statement.period_name} for #{@statement.work.title} again. It updates in a moment."
      rescue Statement::Refused => e
        redirect_back fallback_location: work_tab_path(@statement.work), alert: e.message
      end
    end
  end
end

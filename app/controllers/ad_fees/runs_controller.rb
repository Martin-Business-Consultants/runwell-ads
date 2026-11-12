module AdFees
  # Works out a month's fees now rather than waiting for the run day: every active plan, or one
  # piece of work's. Months already invoiced or skipped are left alone; the rest are worked out
  # again from LuminAds, in the background.
  class RunsController < ApplicationController
    allow_staff
    require_permission :manage_ad_fees
    agent_tool :calculate_ad_fees, on: :create, title: "Work out a month's ad fees now",
      description: "period: any date in the month (default: last month). work_id: just this work (default: every active plan). Reads spend from LuminAds in the background, works out each fee, drafts its QuickBooks invoice if the install drafts them, and opens a review task. Months already invoiced or skipped are left alone. list_ad_fee_statements shows the result a moment later.",
      params: { period: "date", work_id: "integer" }, next_tools: %i[list_ad_fee_statements]

    def create
      period = params[:period].present? ? Date.iso8601(params[:period].to_s).beginning_of_month : Date.current.prev_month.beginning_of_month
      plans = Plan.billable_in(period)
      plans = plans.where(work_id: params[:work_id]) if params[:work_id].present?
      settled = Statement.in_period(period).where.not(state: "calculated").select(:plan_id)
      plans = plans.where.not(id: settled).to_a
      return redirect_back(fallback_location: ad_fees_statements_path, alert: Setting.current.luminads_blocker + ".") if Setting.current.luminads_blocker
      return redirect_back(fallback_location: ad_fees_statements_path, alert: "Nothing to work out for #{period.strftime("%B %Y")}: no active plan without an invoice for it.") if plans.empty?

      plans.each { CalculateJob.perform_later(it, period) }
      redirect_back fallback_location: ad_fees_statements_path(period: period.strftime("%Y-%m")),
        notice: "Working out #{period.strftime("%B %Y")} for #{plans.size} #{helpers.term(:work, count: plans.size).downcase}. It shows here in a moment."
    rescue Date::Error
      redirect_back fallback_location: ad_fees_statements_path, alert: "period isn’t a date (YYYY-MM-DD)."
    end
  end
end

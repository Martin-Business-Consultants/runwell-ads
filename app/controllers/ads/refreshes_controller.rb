module Ads
  # Reads a month's figures again from LuminAds now, in the background: every active ad service, or
  # one piece of work's. Months already invoiced or skipped are left alone.
  class RefreshesController < ApplicationController
    allow_staff
    require_permission :manage_ads
    agent_tool :refresh_ad_costs, on: :create, title: "Read ad services' costs again from LuminAds now",
      description: "period: any date in the month (default: this month). work_id: just this work (default: every active ad service). Reads spend in the background and works out each fee; list_ad_costs shows the result a moment later. Months already invoiced or skipped are left alone.",
      params: { period: "date", work_id: "integer" }, next_tools: %i[list_ad_costs]

    def create
      period = params[:period].present? ? Date.iso8601(params[:period].to_s).beginning_of_month : Date.current.beginning_of_month
      blocker = Setting.current.luminads_blocker
      return redirect_back(fallback_location: ads_statements_path, alert: "#{blocker}.") if blocker

      plans = Plan.live_in(period)
      plans = plans.where(work_id: params[:work_id]) if params[:work_id].present?
      settled = Statement.in_period(period).where(state: %w[invoiced skipped]).select(:plan_id)
      plans = plans.where.not(id: settled).to_a
      return redirect_back(fallback_location: ads_statements_path, alert: "Nothing to read for #{period.strftime("%B %Y")}: no active ad service that isn’t settled.") if plans.empty?

      plans.each { RefreshPlanJob.perform_later(it, period) }
      redirect_back fallback_location: ads_statements_path(period: period.strftime("%Y-%m")),
        notice: "Reading #{period.strftime("%B %Y")} from LuminAds for #{plans.size} #{helpers.term(:work, count: plans.size).downcase}. Refresh the page in a moment."
    rescue Date::Error
      redirect_back fallback_location: ads_statements_path, alert: "period isn’t a date (YYYY-MM-DD)."
    end
  end
end

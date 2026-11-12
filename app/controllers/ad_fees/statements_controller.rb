module AdFees
  # Ad fees in the nav: every month's statement across the work, newest first, filtered by month
  # and state, with what's still needed for any plan that couldn't be worked out.
  class StatementsController < ApplicationController
    allow_staff
    require_permission :manage_ad_fees
    agent_tool :list_ad_fee_statements, on: :index, title: "List ad fee statements",
      description: "Each month's ad fee per piece of work: spend, terms, fee, why (minimum, flat fee or share of spend), state (calculated, invoiced, skipped) and its QuickBooks invoice. period: YYYY-MM for one month; state: one state. Also the plans that couldn't be worked out, and why.",
      params: { period: "string", state: Statement::STATES }

    def index
      @periods = Statement.distinct.order(period_on: :desc).pluck(:period_on)
      @period = Date.strptime(params[:period].to_s, "%Y-%m") rescue nil
      @state = params[:state].presence_in(Statement::STATES)
      @statements = Statement.ordered.includes(:work, :client, :task, :plan)
      @statements = @statements.in_period(@period) if @period
      @statements = @statements.where(state: @state) if @state
      @troubled = Plan.active.where.not(last_error: nil).includes(:work)
      @setting = Setting.current
    end
  end
end

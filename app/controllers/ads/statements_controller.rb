module Ads
  # Ads in the nav: every ad service's figure for a month (this month by default, so the cost is
  # current), filtered by month and state, with what couldn't be read and why.
  class StatementsController < ApplicationController
    allow_staff
    require_permission :manage_ads
    agent_tool :list_ad_costs, on: :index, title: "List what ad services cost",
      description: "Each ad service's month: spend so far (through which day), its management fee and why (minimum, flat fee or share of spend), and, for a month still running, where it's heading at its pace. period: YYYY-MM (default: this month; \"all\" for every month); state: running, final, invoiced or skipped. Also the services that couldn't be read, and why.",
      params: { period: "string", state: Statement::STATES }

    def index
      @periods = (Statement.distinct.pluck(:period_on) | [ Date.current.beginning_of_month ]).sort.reverse
      @period = params[:period] == "all" ? nil : ((Date.strptime(params[:period].to_s, "%Y-%m") rescue nil) || Date.current.beginning_of_month)
      @state = params[:state].presence_in(Statement::STATES)
      @statements = Statement.ordered.includes(:work, :client, :task, :plan)
      @statements = @statements.in_period(@period) if @period
      @statements = @statements.where(state: @state) if @state
      @unread = @period ? Plan.live_in(@period).where.not(id: Statement.in_period(@period).select(:plan_id)).includes(:work, :client).to_a : []
      @troubled = Plan.active.where.not(last_error: nil).includes(:work)
      @setting = Setting.current
    end
  end
end

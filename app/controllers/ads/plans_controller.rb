module Ads
  # Tagging a piece of work as an ad service (PPC), from its Ads tab: which LuminAds accounts are its
  # spend, its fee terms (blank: the defaults), the first month counted, and whether it's paused;
  # while invoicing is on, the QuickBooks customer billed and who reviews each draft. Untagging
  # removes it and its months. Show (for agents) is the service and its months.
  class PlansController < ApplicationController
    allow_staff
    require_permission :manage_ads
    agent_tool :show_ppc_service, on: :show, title: "Show a piece of work's ad service and what it costs",
      description: "work_ref: the work (its ref or title). Whether it's tagged PPC, its LuminAds accounts and fee terms (its own or the defaults), this month so far with where it's heading, and each month's figure."
    agent_tool :tag_ppc_service, on: :update, title: "Tag a piece of work as a PPC service, or change its ad settings",
      description: "work_ref: the work. kind: ppc. luminads_account_ids: the LuminAds ad accounts whose spend counts (list_ads_choices shows them). rule: greater_of, flat or percent; minimum_cents (whole cents, 100000 is $1,000) and percent (20 for 20%): leave any blank for the install's default. starts_on: the first month counted (YYYY-MM-DD, any day of it). active: false pauses it, keeping its months. quickbooks_customer_id and reviewer_id matter only while invoicing is on.",
      params: { plan: { kind: Plan::KINDS.keys, luminads_account_ids: "integer[]", rule: [ "", *Terms::RULES.keys ], minimum_cents: "integer",
        percent: "number", starts_on: "date", active: "boolean", quickbooks_customer_id: "string", reviewer_id: "integer" } },
      next_tools: %i[show_ppc_service refresh_ad_costs]
    agent_tool :untag_ppc_service, on: :destroy, title: "Untag a piece of work as an ad service",
      description: "Removes its ad settings and its months' figures here. Invoices already drafted stay in QuickBooks."

    before_action { @work = Work.find_by!(ref: params[:work_ref]) }

    def show
      @plan = @work.ads_plan
      @statements = @plan ? @plan.statements.ordered.includes(:task) : Statement.none
      respond_to do |format|
        format.html { redirect_to work_tab_path(@work) }
        format.json
      end
    end

    def update
      plan = @work.ads_plan || @work.build_ads_plan
      attributes = params.fetch(:plan, {}).permit(:kind, :quickbooks_customer_id, :rule, :minimum_cents, :percent, :starts_on, :reviewer_id, :active, luminads_account_ids: [])
      attributes[:luminads_accounts] = accounts_for(attributes.delete(:luminads_account_ids)) if attributes.key?(:luminads_account_ids)
      if attributes.key?(:quickbooks_customer_id)
        attributes[:quickbooks_customer_name] = Directory.quickbooks_customers.items.find { it["id"] == attributes[:quickbooks_customer_id].to_s }&.dig("name")
      end
      attributes[:starts_on] = Date.iso8601(attributes[:starts_on]).beginning_of_month if attributes[:starts_on].present?
      created = plan.new_record?
      if plan.update(attributes)
        @work.record_event!(created ? "ads.tagged" : "ads.changed", payload: { kind: plan.kind, terms: plan.terms.to_s, accounts: plan.account_names, active: plan.active })
        RefreshPlanJob.perform_later(plan, Date.current.beginning_of_month) if plan.active && plan.account_ids.any? && Setting.current.luminads_ready?
        redirect_to work_tab_path(@work), notice: plan_notice(plan, created)
      else
        redirect_to work_tab_path(@work), alert: plan.errors.full_messages.to_sentence
      end
    rescue Date::Error
      redirect_to work_tab_path(@work), alert: "The first month counted isn’t a date (YYYY-MM-DD)."
    end

    def destroy
      plan = @work.ads_plan or return redirect_to(work_tab_path(@work), alert: "#{@work.title} isn’t tagged as an ad service.")
      plan.destroy!
      @work.record_event!("ads.untagged", payload: { kind: plan.kind })
      redirect_to work_tab_path(@work), notice: "#{@work.title} is no longer tagged #{plan.kind_name}. Invoices already drafted stay in QuickBooks."
    end

    private
      # Each picked account with its name, kept so the tab shows them without asking LuminAds.
      def accounts_for(ids)
        known = Directory.luminads_accounts.items.index_by { it["id"].to_s }
        Array(ids).compact_blank.uniq.map { |id| { "id" => id.to_i, "name" => known[id.to_s]&.dig("name") || "LuminAds account #{id}" } }
      end

      def plan_notice(plan, created)
        notice = created ? "#{@work.title} is tagged #{plan.kind_name}: its fee is #{plan.terms}." : "Saved: #{@work.title}’s fee is #{plan.terms}."
        notice += " It’s paused." unless plan.active
        if (blocker = plan.blocker)
          notice += " Still needed: #{blocker}."
        elsif plan.active
          notice += " Reading this month from LuminAds now."
        end
        notice
      end
  end
end

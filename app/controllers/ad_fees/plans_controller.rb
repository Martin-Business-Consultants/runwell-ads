module AdFees
  # A piece of work's ad fee plan, from its Ad fees tab: which LuminAds accounts are its spend,
  # the QuickBooks customer billed, its own terms (blank: the defaults), the first month billed,
  # who reviews it, and whether it's billed at all. Show (for agents) is the plan and its months.
  class PlansController < ApplicationController
    allow_staff
    require_permission :manage_ad_fees
    agent_tool :show_ad_fee_plan, on: :show, title: "Show a piece of work's ad fee plan and its months",
      description: "work_ref: the work (its ref or title). Its LuminAds accounts, QuickBooks customer, terms (its own, or the defaults), and each month's statement: spend, fee, why, and its QuickBooks invoice."
    agent_tool :set_ad_fee_plan, on: :update, title: "Set up or change a piece of work's ad fee",
      description: "work_ref: the work. luminads_account_ids: the LuminAds ad accounts whose spend counts (list_ad_fee_choices shows them). quickbooks_customer_id: the QuickBooks customer billed. rule: greater_of, flat or percent; minimum_cents (whole cents) and percent (20 for 20%): leave any blank to use the install's default. starts_on: the first month billed (YYYY-MM-DD, any day of it). reviewer_id: who reviews each month's draft (blank: the default). active: false stops billing it, keeping its months.",
      params: { plan: { luminads_account_ids: "integer[]", quickbooks_customer_id: "string", rule: [ "", *Terms::RULES.keys ], minimum_cents: "integer",
        percent: "number", starts_on: "date", reviewer_id: "integer", active: "boolean" } },
      next_tools: %i[show_ad_fee_plan calculate_ad_fees]
    agent_tool :remove_ad_fee_plan, on: :destroy, title: "Remove a piece of work's ad fee plan",
      description: "Deletes the plan and its months' statements here. Invoices already drafted stay in QuickBooks."

    before_action { @work = Work.find_by!(ref: params[:work_ref]) }

    def show
      @plan = @work.ad_fees_plan
      @statements = @plan ? @plan.statements.ordered.includes(:task) : Statement.none
      respond_to do |format|
        format.html { redirect_to work_tab_path(@work) }
        format.json
      end
    end

    def update
      plan = @work.ad_fees_plan || @work.build_ad_fees_plan
      attributes = params.expect(plan: [ :quickbooks_customer_id, :rule, :minimum_cents, :percent, :starts_on, :reviewer_id, :active, luminads_account_ids: [] ])
      if attributes.key?(:luminads_account_ids)
        attributes[:luminads_accounts] = accounts_for(attributes.delete(:luminads_account_ids))
      end
      if attributes.key?(:quickbooks_customer_id)
        attributes[:quickbooks_customer_name] = Directory.quickbooks_customers.items.find { it["id"] == attributes[:quickbooks_customer_id].to_s }&.dig("name")
      end
      attributes[:starts_on] = Date.iso8601(attributes[:starts_on]).beginning_of_month if attributes[:starts_on].present?
      created = plan.new_record?
      if plan.update(attributes)
        @work.record_event!(created ? "ad_fees.plan_created" : "ad_fees.plan_changed", payload: { terms: plan.terms.to_s, accounts: plan.account_names, active: plan.active })
        redirect_to work_tab_path(@work), notice: plan_notice(plan)
      else
        redirect_to work_tab_path(@work), alert: plan.errors.full_messages.to_sentence
      end
    rescue Date::Error
      redirect_to work_tab_path(@work), alert: "The first month billed isn’t a date (YYYY-MM-DD)."
    end

    def destroy
      plan = @work.ad_fees_plan or return redirect_to(work_tab_path(@work), alert: "#{@work.title} has no ad fee.")
      plan.destroy!
      @work.record_event!("ad_fees.plan_removed")
      redirect_to work_tab_path(@work), notice: "Removed #{@work.title}’s ad fee. Invoices already drafted stay in QuickBooks."
    end

    private
      # Each picked account with its name, kept so the tab shows them without asking LuminAds.
      def accounts_for(ids)
        known = Directory.luminads_accounts.items.index_by { it["id"].to_s }
        Array(ids).compact_blank.uniq.map { |id| { "id" => id.to_i, "name" => known[id.to_s]&.dig("name") || "LuminAds account #{id}" } }
      end

      def plan_notice(plan)
        notice = "#{@work.title} is billed #{plan.terms}"
        notice += plan.active ? ", from #{plan.starts_on.strftime("%B %Y")}." : ". Billing is off."
        notice += " Still needed: #{plan.blocker}." if plan.blocker
        notice
      end
  end
end

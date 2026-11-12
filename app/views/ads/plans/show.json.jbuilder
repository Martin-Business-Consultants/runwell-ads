json.merge! agent_ref(@work)
if @plan
  current = @statements.find { it.period_on == Date.current.beginning_of_month }
  now = current ? " #{current.period_on.strftime("%B")} so far: #{money(current.spend_cents)} spent through #{current.through_on.strftime("%b %-d")}, a fee of #{money(current.fee_cents)}" \
    "#{", heading for #{money(current.projected_fee_cents)}" if current.partial?}." : " This month isn’t read yet."
  json.summary "#{@work.title} is tagged #{@plan.kind_name}#{" (paused)" unless @plan.active}; its fee is #{@plan.terms}#{" (its own terms)" if @plan.own_terms?}.#{now}" \
    "#{" Still needed: #{@plan.blocker}." if @plan.blocker}"
  json.tagged @plan.kind
  json.plan do
    json.terms @plan.terms.to_s
    json.extract! @plan, :kind, :rule, :minimum_cents, :active, :starts_on, :quickbooks_customer_id, :quickbooks_customer_name, :last_error
    json.percent @plan.percent&.to_f
    json.own_terms @plan.own_terms?
    json.luminads_accounts @plan.luminads_accounts
    json.reviewer @plan.reviewer ? agent_ref(@plan.reviewer) : nil
  end
  json.statements @statements, partial: "ads/statements/statement", as: :statement
else
  json.summary "#{@work.title} isn’t tagged as an ad service. tag_ppc_service tags it."
  json.tagged nil
end

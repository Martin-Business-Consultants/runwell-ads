json.merge! agent_ref(@work)
if @plan
  json.summary "#{@work.title} is billed #{@plan.terms}#{" (its own terms)" if @plan.own_terms?}, from #{@plan.starts_on.strftime("%B %Y")}" \
    "#{", billing off" unless @plan.active}. #{@statements.size} #{"month".pluralize(@statements.size)} worked out.#{" Still needed: #{@plan.blocker}." if @plan.blocker}"
  json.plan do
    json.terms @plan.terms.to_s
    json.extract! @plan, :rule, :minimum_cents, :active, :starts_on, :quickbooks_customer_id, :quickbooks_customer_name, :last_error
    json.percent @plan.percent&.to_f
    json.own_terms @plan.own_terms?
    json.luminads_accounts @plan.luminads_accounts
    json.reviewer @plan.reviewer ? agent_ref(@plan.reviewer) : nil
  end
  json.statements @statements, partial: "ad_fees/statements/statement", as: :statement
else
  json.summary "#{@work.title} has no ad fee. set_ad_fee_plan sets one up."
  json.plan nil
end

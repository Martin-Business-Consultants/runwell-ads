statements = @statements.to_a
billed = statements.reject(&:skipped?)
json.summary "#{statements.size} #{"statement".pluralize(statements.size)}#{" for #{@period.strftime("%B %Y")}" if @period}: " \
  "#{money(billed.sum(&:fee_cents))} in fees on #{money(billed.sum(&:spend_cents))} of ad spend; " \
  "#{statements.count(&:calculated?)} to draft, #{statements.count(&:invoiced?)} drafted, #{statements.count(&:skipped?)} skipped." \
  "#{" #{@troubled.size} couldn’t be worked out." if @troubled.any?}"
json.total_fee_cents billed.sum(&:fee_cents)
json.statements statements do |statement|
  json.work agent_ref(statement.work)
  json.client agent_ref(statement.client)
  json.partial! "ad_fees/statements/statement", statement: statement
end
json.not_worked_out @troubled do |plan|
  json.work agent_ref(plan.work)
  json.error plan.last_error
end

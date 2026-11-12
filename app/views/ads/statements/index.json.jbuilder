statements = @statements.to_a
counted = statements.reject(&:skipped?)
heading = counted.any?(&:partial?) ? ", heading for #{money(counted.sum(&:projected_fee_cents))} at this pace" : ""
json.summary "#{@period ? @period.strftime("%B %Y") : "Every month"}: #{statements.size} #{"figure".pluralize(statements.size)}, " \
  "#{money(counted.sum(&:fee_cents))} in fees on #{money(counted.sum(&:spend_cents))} of ad spend#{heading}." \
  "#{" Not read yet: #{@unread.map { it.work.title }.join(", ")}." if @unread.any?}" \
  "#{" Couldn’t be read: #{@troubled.size}." if @troubled.any?}"
json.total_fee_cents counted.sum(&:fee_cents)
json.total_spend_cents counted.sum(&:spend_cents)
json.statements statements do |statement|
  json.work agent_ref(statement.work)
  json.client agent_ref(statement.client)
  json.partial! "ads/statements/statement", statement: statement
end
json.not_read_yet @unread.map { agent_ref(it.work) }
json.not_read @troubled do |plan|
  json.work agent_ref(plan.work)
  json.error plan.last_error
end

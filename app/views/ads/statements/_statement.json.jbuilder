json.extract! statement, :id, :state, :spend_cents, :fee_cents, :basis, :rule, :minimum_cents
json.period statement.period_on.strftime("%Y-%m")
json.period_name statement.period_name
json.through_on statement.through_on
json.percent statement.percent.to_f
json.spend money(statement.spend_cents)
json.fee money(statement.fee_cents)
json.terms statement.terms.to_s
json.why statement.explanation
json.refreshed_at statement.refreshed_at
if statement.partial?
  json.heading_for_spend_cents statement.projected_spend_cents
  json.heading_for_fee_cents statement.projected_fee_cents
  json.heading_for_fee money(statement.projected_fee_cents)
end
json.spend_by_account statement.spend_detail
json.drafting statement.invoicing?
json.invoice statement.invoice_qbo_id ? { id: statement.invoice_qbo_id, number: statement.invoice_doc_number, sent: false, drafted_at: statement.invoiced_at } : nil
json.skip_reason statement.skip_reason
json.error statement.last_error
json.review_task statement.task ? agent_ref(statement.task) : nil

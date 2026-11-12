json.extract! statement, :id, :state, :spend_cents, :fee_cents, :basis, :rule, :minimum_cents
json.period statement.period_on.strftime("%Y-%m")
json.period_name statement.period_name
json.percent statement.percent.to_f
json.spend money(statement.spend_cents)
json.fee money(statement.fee_cents)
json.terms statement.terms.to_s
json.why statement.explanation
json.drafting statement.invoicing?
json.spend_by_account statement.spend_detail
json.invoice statement.invoice_qbo_id ? { id: statement.invoice_qbo_id, number: statement.invoice_doc_number, sent: false, drafted_at: statement.invoiced_at } : nil
json.skip_reason statement.skip_reason
json.error statement.last_error
json.review_task statement.task ? agent_ref(statement.task) : nil

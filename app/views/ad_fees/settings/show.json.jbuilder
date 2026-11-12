json.summary "Ad fees are #{@setting.terms} by default, worked out on day #{@setting.run_on_day} for the month before" \
  "#{", drafted in QuickBooks unsent" if @setting.draft_invoices}. LuminAds: #{@setting.luminads_blocker || "connected"}. QuickBooks: #{@setting.invoice_blocker || "ready"}."
json.default_rule @setting.default_rule
json.default_minimum_cents @setting.default_minimum_cents
json.default_minimum money(@setting.default_minimum_cents)
json.default_percent @setting.default_percent.to_f
json.run_on_day @setting.run_on_day
json.draft_invoices @setting.draft_invoices
json.reviewer @setting.reviewer ? agent_ref(@setting.reviewer) : nil
json.quickbooks_item_id @setting.quickbooks_item_id
json.quickbooks_item_name @setting.quickbooks_item_name
json.quickbooks_items @items.items
json.luminads_connected @setting.luminads_blocker.nil?
json.luminads_url @setting.luminads_url
json.quickbooks_company @connection.company_name if @connection.connected?
json.quickbooks_blocker @setting.invoice_blocker

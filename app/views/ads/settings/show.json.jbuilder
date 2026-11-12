json.summary "Ad services' fees are #{@setting.terms} by default; a month is final on day #{@setting.run_on_day} of the next. " \
  "LuminAds: #{@setting.luminads_blocker || "connected"}. Invoicing is #{@setting.invoicing ? "on#{" but #{@setting.invoice_blocker}" if @setting.invoice_blocker}" : "off"}."
json.default_rule @setting.default_rule
json.default_minimum_cents @setting.default_minimum_cents
json.default_minimum money(@setting.default_minimum_cents)
json.default_percent @setting.default_percent.to_f
json.run_on_day @setting.run_on_day
json.luminads_connected @setting.luminads_blocker.nil?
json.luminads_url @setting.luminads_url
json.invoicing @setting.invoicing
json.reviewer @setting.reviewer ? agent_ref(@setting.reviewer) : nil
json.quickbooks_item_id @setting.quickbooks_item_id
json.quickbooks_item_name @setting.quickbooks_item_name
json.quickbooks_items @items.items
json.quickbooks_company @connection.company_name if @connection.connected?

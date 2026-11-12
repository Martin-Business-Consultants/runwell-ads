json.summary "#{@accounts.items.size} LuminAds #{"account".pluralize(@accounts.items.size)}#{" (#{@accounts.error})" if @accounts.error}; " \
  "#{@customers.items.size} QuickBooks #{"customer".pluralize(@customers.items.size)}#{" (#{@customers.error})" if @customers.error}."
json.luminads_accounts @accounts.items
json.quickbooks_customers @customers.items

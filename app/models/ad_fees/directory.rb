module AdFees
  # The choices a plan's form offers, from the other services: LuminAds' ad accounts and
  # QuickBooks' customers and products. Kept for ten minutes so the Ad fees tab doesn't ask both
  # services every time it opens; a service that can't be reached gives an empty list and says why.
  module Directory
    TTL = 10.minutes

    Listing = Data.define(:items, :error)

    def self.luminads_accounts
      fetch("luminads_accounts") do
        Luminads.new.accounts.map { { "id" => it["id"], "name" => account_name(it), "connected" => it["connected"] } }
      end
    end

    def self.quickbooks_customers
      fetch("quickbooks_customers") do
        QuickbooksApi.new.customers.map { { "id" => it["Id"], "name" => it["DisplayName"] } }.sort_by { it["name"].to_s.downcase }
      end
    end

    def self.quickbooks_items
      fetch("quickbooks_items") do
        QuickbooksApi.new.items.map { { "id" => it["Id"], "name" => it["Name"] } }.sort_by { it["name"].to_s.downcase }
      end
    end

    def self.forget! = %w[luminads_accounts quickbooks_customers quickbooks_items].each { Rails.cache.delete("ad_fees/#{it}") }

    def self.account_name(account)
      platform = account["platform"].to_s.tr("_", " ").split.map(&:capitalize).join(" ")
      platform.present? ? "#{account["name"]} (#{platform})" : account["name"].to_s
    end

    def self.fetch(key)
      Listing.new(items: Rails.cache.fetch("ad_fees/#{key}", expires_in: TTL) { yield }, error: nil)
    rescue Luminads::Error, QuickbooksApi::Error => e
      Listing.new(items: [], error: e.message)
    end
  end
end

module AdFees
  # LuminAds' API, as much of it as ad fees read: the ad accounts the token can see, and what each
  # spent between two dates (GET /api/v1/accounts/:id/performance, its totals' cost_cents, the same
  # figure as LuminAds' own reports). Read only. Each answer is LuminAds' envelope:
  # { status, summary, data }.
  class Luminads
    require "net/http"

    class Error < StandardError; end

    Spend = Data.define(:total_cents, :detail)

    def initialize(setting = Setting.current)
      raise Error, setting.luminads_blocker if setting.luminads_blocker

      @base = setting.luminads_url
      @token = setting.luminads_token
    end

    # [{ "id" => 12, "name" => "Bloom", "domain" => "bloom.com", "platform" => "google_ads", "connected" => true }]
    def accounts
      Array(get("/api/v1/accounts").dig("data", "accounts"))
    end

    # Spend across the accounts (as a plan keeps them: id and name) over a range of dates, in cents.
    def spend(accounts, range)
      detail = accounts.map do |account|
        totals = get("/api/v1/accounts/#{account["id"]}/performance", start_date: range.first.iso8601, end_date: range.last.iso8601).dig("data", "totals") || {}
        { "id" => account["id"], "name" => account["name"], "cents" => totals["cost_cents"].to_i }
      end
      Spend.new(total_cents: detail.sum { it["cents"] }, detail: detail)
    end

    private
      def get(path, **query)
        uri = URI("#{@base}#{path}")
        uri.query = query.to_query if query.any?
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{@token}"
        request["Accept"] = "application/json"
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 60) { it.request(request) }
        body = begin
          JSON.parse(response.body.to_s)
        rescue JSON::ParserError
          {}
        end
        return body if response.is_a?(Net::HTTPSuccess) && body["status"] != "error"

        raise Error, "LuminAds answered #{response.code}: #{body["summary"] || body["error"] || response.body.to_s.truncate(200)}"
      rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
        raise Error, "Couldn’t reach LuminAds at #{@base}: #{e.message}"
      end
  end
end

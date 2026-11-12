module Ads
  # The QuickBooks Online accounting API, as much of it as the Ads plugin uses. Reads: the company, its
  # customers and its products and services. One write: create an invoice, which it leaves
  # unsent (EmailStatus NotSet) for someone to check and send from QuickBooks. Nothing sends,
  # changes or deletes anything in the books.
  class QuickbooksApi
    require "net/http"

    MINOR_VERSION = 75

    class Error < StandardError; end

    def initialize(connection = QuickbooksConnection.current)
      raise Error, "QuickBooks isn’t connected. Connect it in Settings › Plugins › Ads." unless connection&.connected?

      @connection = connection
      @oauth = QuickbooksOauth.new(connection)
    end

    attr_reader :connection

    # QuickBooks' SQL-ish dialect, paged: Intuit caps a page at 1000 whatever you ask for.
    def query_all(entity, where: nil, page_size: 500)
      results = []
      position = 1
      loop do
        statement = [ "SELECT * FROM #{entity}", ("WHERE #{where}" if where), "STARTPOSITION #{position} MAXRESULTS #{page_size}" ].compact.join(" ")
        page = get("/query", query: statement).dig("QueryResponse", entity) || []
        results.concat(page)
        break if page.size < page_size

        position += page_size
      end
      results
    end

    def company = get("/companyinfo/#{connection.realm_id}")["CompanyInfo"]
    def customers = query_all("Customer", where: "Active = true")
    def items = query_all("Item", where: "Active = true AND Type IN ('Service', 'NonInventory')")

    # The one write. request_id makes a retry of the same request a no-op on Intuit's side.
    def create_invoice(payload, request_id:) = post("/invoice", payload, requestid: request_id)["Invoice"]

    private
      def get(path, **query)
        uri = URI("#{connection.api_host}/v3/company/#{connection.realm_id}#{path}")
        uri.query = query.compact.merge(minorversion: MINOR_VERSION).to_query
        request(Net::HTTP::Get.new(uri))
      end

      def post(path, payload, **query)
        uri = URI("#{connection.api_host}/v3/company/#{connection.realm_id}#{path}")
        uri.query = query.compact.merge(minorversion: MINOR_VERSION).to_query
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(payload)
        request(request)
      end

      def request(request)
        request["Authorization"] = "Bearer #{@oauth.access_token!}"
        request["Accept"] = "application/json"
        uri = request.uri
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) { it.request(request) }
        body = begin
          JSON.parse(response.body.to_s)
        rescue JSON::ParserError
          {}
        end
        return body if response.is_a?(Net::HTTPSuccess) && body["Fault"].nil?

        fault = body.dig("Fault", "Error")&.first
        raise Error, "QuickBooks returned #{response.code}: #{fault ? "#{fault["Message"]}. #{fault["Detail"]}" : response.body.to_s.truncate(300)}"
      rescue QuickbooksOauth::Error => e
        connection.note_error!(e.message)
        raise Error, e.message
      rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
        raise Error, "Couldn’t reach QuickBooks: #{e.message}"
      end
  end
end

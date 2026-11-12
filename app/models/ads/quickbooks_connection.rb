module Ads
  # The Ads plugin's own connection to one QuickBooks company (one row), so the plugin needs no other.
  # Two halves that arrive at different times: the credentials of the business's own Intuit app,
  # pasted into Settings › Plugins › Ads, then after Intuit's consent screen the tokens and
  # the realm id that say which company file this is.
  class QuickbooksConnection < ::ApplicationRecord
    self.table_name = "ads_quickbooks_connections"

    # A client secret mints tokens, and an access token reads a company's whole books.
    encrypts :client_secret
    encrypts :access_token
    encrypts :refresh_token

    ENVIRONMENTS = %w[sandbox production].freeze

    # Intuit's access tokens last an hour. Refresh early: a run that starts at 59 minutes
    # should not fail at 61.
    REFRESH_MARGIN = 5.minutes

    validates :environment, inclusion: { in: ENVIRONMENTS }
    validate :ensure_singleton, on: :create

    def self.current = first
    def self.for_settings = first || new(environment: "production")

    def configured? = client_id.present? && client_secret.present?
    def connected? = configured? && realm_id.present? && refresh_token.present?
    def sandbox? = environment == "sandbox"

    # Pointing production credentials at the sandbox host answers with a confusing 401.
    def api_host = sandbox? ? "https://sandbox-quickbooks.api.intuit.com" : "https://quickbooks.api.intuit.com"
    # Where someone opens an invoice to check and send it.
    def invoice_url(qbo_id) = "https://#{"sandbox." if sandbox?}qbo.intuit.com/app/invoice?txnId=#{qbo_id}"

    def access_expired? = access_expires_at.nil? || access_expires_at <= REFRESH_MARGIN.from_now

    # The refresh token expires (~100 days) and rotates on every use, so a connection left
    # idle for months has to be re-consented rather than refreshed.
    def refresh_expired? = refresh_expires_at.present? && refresh_expires_at <= Time.current

    def store_tokens!(payload)
      update!(
        access_token: payload["access_token"],
        refresh_token: payload["refresh_token"].presence || refresh_token,
        access_expires_at: payload["expires_in"].to_i.seconds.from_now,
        refresh_expires_at: payload["x_refresh_token_expires_in"].presence&.to_i&.seconds&.from_now || refresh_expires_at,
        last_error: nil
      )
    end

    def disconnect!
      update!(realm_id: nil, company_name: nil, access_token: nil, refresh_token: nil, access_expires_at: nil,
        refresh_expires_at: nil, connected_at: nil, last_error: nil, oauth_state: nil)
    end

    def note_error!(message) = update_columns(last_error: message.to_s.truncate(500), updated_at: Time.current)

    private
      def ensure_singleton
        errors.add(:base, "QuickBooks is already set up") if QuickbooksConnection.exists?
      end
  end
end

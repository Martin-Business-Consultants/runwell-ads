module Ads
  # The keys to the other services, saved only in the browser (never by a token): LuminAds' address
  # and token, and the business's Intuit app. Destroy disconnects QuickBooks; nothing in the books
  # changes.
  class ConnectionsController < ApplicationController
    allow_staff
    require_permission :manage_settings
    browser_only :update, :destroy, reason: "keys to LuminAds and QuickBooks are entered by a person in the browser"

    def update
      if params.key?(:luminads)
        save_luminads
      else
        save_quickbooks
      end
    end

    def destroy
      connection = QuickbooksConnection.for_settings
      QuickbooksOauth.new(connection).revoke! if connection.persisted?
      connection.disconnect! if connection.persisted?
      Directory.forget!
      redirect_to ads_settings_path, notice: "Disconnected from QuickBooks. Invoices already drafted stay in QuickBooks."
    end

    private
      def save_luminads
        setting = Setting.current
        attributes = params.expect(luminads: %i[luminads_url luminads_token]).reject { |key, value| key == "luminads_token" && value.blank? }
        if setting.update(attributes)
          Directory.forget!
          listing = Directory.luminads_accounts
          if listing.error
            redirect_to ads_settings_path, alert: "Saved, but LuminAds didn’t answer: #{listing.error}"
          else
            redirect_to ads_settings_path, notice: "Connected to LuminAds: #{listing.items.size} ad #{"account".pluralize(listing.items.size)}."
          end
        else
          redirect_to ads_settings_path, alert: setting.errors.full_messages.to_sentence
        end
      end

      # The secret is write-only on the page: a blank field keeps what is saved.
      def save_quickbooks
        connection = QuickbooksConnection.for_settings
        attributes = params.expect(quickbooks: %i[client_id client_secret environment]).reject { |key, value| key == "client_secret" && value.blank? }
        if connection.update(attributes)
          redirect_to ads_settings_path, notice: connection.connected? ? "Saved." : "Saved. Now sign in with QuickBooks to connect."
        else
          redirect_to ads_settings_path, alert: connection.errors.full_messages.to_sentence
        end
      end
  end
end

module Ads
  # Drafts a statement's invoice in QuickBooks, unsent, once someone asked (Draft invoice,
  # draft_ad_invoice). A failure is kept on the statement, which can be drafted again.
  class InvoiceJob < ApplicationJob
    queue_as :default

    def perform(statement)
      return unless Runwell::Plugins.enabled?(:ads)

      statement.draft_invoice!
    rescue QuickbooksApi::Error, Statement::Refused => e
      Rails.logger.warn("[ads] statement #{statement.id}: #{e.message}")
    end
  end
end

module AdFees
  # Works out one plan's fee for one month, on request (Calculate, Recalculate, calculate_ad_fees):
  # a statement already invoiced or skipped is left as it is.
  class CalculateJob < ApplicationJob
    queue_as :default

    def perform(plan, period)
      return unless Runwell::Plugins.enabled?(:ad_fees)

      Statement.run!(plan, period)
    rescue Luminads::Error, QuickbooksApi::Error, Statement::Refused => e
      Rails.logger.warn("[ad_fees] #{plan.work&.ref} #{period}: #{e.message}")
    end
  end
end

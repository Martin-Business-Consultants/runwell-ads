module Ads
  # Reads one service's month again on request (Refresh, refresh_ad_costs). A month already invoiced
  # or skipped is left as it is.
  class RefreshPlanJob < ApplicationJob
    queue_as :default

    def perform(plan, period)
      return unless Runwell::Plugins.enabled?(:ads)

      Statement.run!(plan, period)
    rescue Luminads::Error, QuickbooksApi::Error, Statement::Refused => e
      Rails.logger.warn("[ads] #{plan.work&.ref} #{period}: #{e.message}")
    end
  end
end

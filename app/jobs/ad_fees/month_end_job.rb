module AdFees
  # Nightly: once the month has turned and its run day has come (Settings › Plugins › Ad fees, the
  # 3rd by default, so ad platforms have settled last month's spend), works out last month's fee
  # for every plan that has none yet. A night that's missed is caught up the next; a plan LuminAds
  # can't answer for keeps its error and is tried again the next night.
  class MonthEndJob < ApplicationJob
    queue_as :default

    def perform(today = Date.current)
      return unless Runwell::Plugins.enabled?(:ad_fees)

      setting = Setting.current
      return if today.day < setting.run_on_day || setting.luminads_blocker

      period = today.prev_month.beginning_of_month
      done = Statement.in_period(period).select(:plan_id)
      Plan.billable_in(period).where.not(id: done).includes(:work, :client, :reviewer).find_each do |plan|
        Statement.run!(plan, period, setting: setting)
      rescue Luminads::Error, QuickbooksApi::Error, Statement::Refused, ActiveRecord::RecordInvalid => e
        Rails.logger.warn("[ad_fees] #{plan.work&.ref} #{period}: #{e.message}")
      end
    end
  end
end

module Ads
  # Nightly: every active ad service's figure for this month so far, read again from LuminAds, so the
  # cost on its Ads tab and the Ads page is never more than a day old. Last month is read again too
  # until it's final: ad platforms settle a month's spend for a few days after it ends, so it becomes
  # final on the run day (Settings › Plugins › Ads, the 3rd by default), and then, while invoicing is
  # on, is drafted in QuickBooks. A service LuminAds can't answer for keeps its error and is tried
  # again the next night.
  class RefreshJob < ApplicationJob
    queue_as :default

    def perform
      return unless Runwell::Plugins.enabled?(:ads)

      setting = Setting.current
      return if setting.luminads_blocker

      current = Date.current.beginning_of_month
      previous = current.prev_month
      settled = Statement.in_period(previous).where.not(state: "running").select(:plan_id)
      each_plan(Plan.live_in(previous).where.not(id: settled)) { Statement.run!(it, previous, setting: setting) }
      each_plan(Plan.live_in(current)) { Statement.run!(it, current, setting: setting) }
    end

    private
      def each_plan(plans)
        plans.includes(:work, :client, :reviewer).find_each do |plan|
          yield plan
        rescue Luminads::Error, QuickbooksApi::Error, Statement::Refused, ActiveRecord::RecordInvalid => e
          Rails.logger.warn("[ads] #{plan.work&.ref}: #{e.message}")
        end
      end
  end
end

module Ads
  # The Ads pages and actions use the core's layout, and vanish while it's switched off.
  class ApplicationController < ::ApplicationController
    layout "application"

    before_action { head :not_found unless Runwell::Plugins.enabled?(:ads) }

    private
      def set_statement
        @statement = Statement.includes(:plan, :work, :client).find(params[:statement_id] || params[:id])
      end

      # Back to the work's Ads tab, where its statements are listed.
      def work_tab_path(work) = main_app.work_path(work, tab: "plugin-ads")
  end
end

module Ads
  # A Runwell plugin for ad services. A piece of work is tagged as PPC on its Ads tab and linked to
  # its LuminAds accounts; its cost is kept current: spend this month so far and the management fee
  # it comes to ($1,000 a month or 20% of spend, whichever is greater, by default; Settings › Plugins
  # › Ads, and each service may override them), refreshed nightly and on request, final once the
  # month has settled. Invoicing (unsent QuickBooks drafts) is there but off until switched on.
  #
  # It owns its tables (ads_*), points at core records by id, and reaches the core only through the
  # plugin contract. It holds its own QuickBooks sign-in, so it needs no other plugin. Remove it and
  # Runwell runs as before.
  class Engine < ::Rails::Engine
    initializer "ads.routes" do |app|
      app.routes.append do
        scope "ads", module: "ads", as: "ads" do
          resource :settings, only: %i[show update]
          # Keys to other services: LuminAds' token, the Intuit app. Browser only.
          resource :connection, only: %i[update destroy]
          resource :authorization, only: %i[create show]
          resource :refresh, only: :create
          resource :choices, only: :show
          resources :statements, only: :index do
            scope module: :statements do
              resource :invoice, only: :create
              resource :skip, only: %i[create destroy]
            end
          end
          get "work/:work_ref", to: "plans#show", as: :plan
          patch "work/:work_ref", to: "plans#update"
          delete "work/:work_ref", to: "plans#destroy"
        end
      end
    end

    initializer "ads.models" do
      ActiveSupport.on_load(:runwell_work) do
        has_one :ads_plan, class_name: "Ads::Plan", dependent: :destroy
      end
      ActiveSupport.on_load(:runwell_client) do
        has_many :ads_plans, class_name: "Ads::Plan", dependent: :destroy
      end
      # The review task is the core's; losing it leaves the statement standing.
      ActiveSupport.on_load(:runwell_task) do
        has_one :ads_statement, class_name: "Ads::Statement", dependent: :nullify
      end
    end

    config.to_prepare do
      Runwell::Plugins.register :ads, name: "Ads", version: Ads::VERSION, author: "Martin Business Consultants",
        enabled_by_default: false, requires: ">= 5.9.0", homepage: "https://github.com/Martin-Business-Consultants/runwell-ads",
        description: "Ad services, tagged as PPC and linked to LuminAds: what each costs this month so far, its management fee (a minimum or a share of spend, whichever is greater) and where the month is heading, kept current every night. Invoicing through QuickBooks when you switch it on."
      Runwell::Plugins.permission :ads, :manage_ads, name: "Tag ad services and see what they cost", roles: %w[owner manager]
      Runwell::Plugins.slot :work_panel, :ads, "ads/slots/work_panel"
      Runwell::Plugins.slot :work_meta, :ads, "ads/slots/work_meta"
      Runwell::Plugins.nav :ads, "Ads", -> { ads_statements_path if can?(:manage_ads) }, icon: "megaphone"
      Runwell::Plugins.settings :ads, "Ads", -> { ads_settings_path if can?(:manage_settings) }
      Runwell::Plugins.stylesheet :ads, "ads/ads"
      Runwell::Plugins.nightly :ads, -> { Ads::RefreshJob.perform_later }
    end
  end
end

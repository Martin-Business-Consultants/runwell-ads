module AdFees
  # A Runwell plugin: a monthly management fee on a piece of work's ad spend. The terms are
  # $1,000 a month or 20% of spend, whichever is greater, by default (Settings › Plugins › Ad fees),
  # and each piece of work's plan may override them. Spend comes from LuminAds; the fee becomes
  # an unsent invoice in QuickBooks, with a task for someone to review and send it.
  #
  # It owns its tables (ad_fees_*), points at core records by id, and reaches the core only through
  # the plugin contract. It holds its own QuickBooks sign-in, so it needs no other plugin. Remove
  # it and Runwell runs as before.
  class Engine < ::Rails::Engine
    initializer "ad_fees.routes" do |app|
      app.routes.append do
        scope "ad-fees", module: "ad_fees", as: "ad_fees" do
          resource :settings, only: %i[show update]
          # Keys to other services: LuminAds' token, the Intuit app. Browser only.
          resource :connection, only: %i[update destroy]
          resource :authorization, only: %i[create show]
          resource :run, only: :create
          resource :choices, only: :show
          resources :statements, only: :index do
            scope module: :statements do
              resource :invoice, only: :create
              resource :recalculation, only: :create
              resource :skip, only: %i[create destroy]
            end
          end
          get "work/:work_ref", to: "plans#show", as: :plan
          patch "work/:work_ref", to: "plans#update"
          delete "work/:work_ref", to: "plans#destroy"
        end
      end
    end

    initializer "ad_fees.models" do
      ActiveSupport.on_load(:runwell_work) do
        has_one :ad_fees_plan, class_name: "AdFees::Plan", dependent: :destroy
      end
      ActiveSupport.on_load(:runwell_client) do
        has_many :ad_fees_plans, class_name: "AdFees::Plan", dependent: :destroy
      end
      # The review task is the core's; losing it leaves the statement standing.
      ActiveSupport.on_load(:runwell_task) do
        has_one :ad_fees_statement, class_name: "AdFees::Statement", dependent: :nullify
      end
    end

    config.to_prepare do
      Runwell::Plugins.register :ad_fees, name: "Ad fees", version: AdFees::VERSION, author: "Martin Business Consultants",
        enabled_by_default: false, requires: ">= 5.9.0", homepage: "https://github.com/Martin-Business-Consultants/runwell-ad-fees",
        description: "A monthly management fee on ad spend: a minimum or a share of what was spent, whichever is greater, worked out from LuminAds each month and drafted as a QuickBooks invoice for someone to review and send."
      Runwell::Plugins.permission :ad_fees, :manage_ad_fees, name: "Set ad fees and invoice them", roles: %w[owner manager]
      Runwell::Plugins.slot :work_panel, :ad_fees, "ad_fees/slots/work_panel"
      Runwell::Plugins.nav :ad_fees, "Ad fees", -> { ad_fees_statements_path if can?(:manage_ad_fees) }, icon: "megaphone"
      Runwell::Plugins.settings :ad_fees, "Ad fees", -> { ad_fees_settings_path if can?(:manage_settings) }
      Runwell::Plugins.stylesheet :ad_fees, "ad_fees/ad_fees"
      Runwell::Plugins.nightly :ad_fees, -> { AdFees::MonthEndJob.perform_later }
    end
  end
end

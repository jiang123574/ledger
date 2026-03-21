Rails.application.routes.draw do
  # PWA manifest
  get "manifest" => "pwa#manifest", as: :pwa_manifest
  get "manifest.json" => "pwa#manifest"

  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#show"

  resources :transactions do
    collection do
      post :bulk_destroy
    end
  end

  resources :accounts
  resources :categories
  resources :tags, only: [ :index, :create, :update, :destroy ]
  resources :counterparties
  resources :budgets, only: [ :index, :create, :update, :destroy ]
  resources :event_budgets
  resources :plans do
    member do
      post :execute
    end
  end
  resources :receivables do
    member do
      get :settle
      post :settle
    end
  end
  resources :recurring, controller: "recurring", only: [ :index, :new, :create, :edit, :update, :destroy ] do
    member do
      post :execute
    end
  end

  resources :imports, only: [ :new, :create ] do
    collection do
      post :preview
      get :templates
    end
  end

  resources :backups, only: [ :index, :create, :destroy ] do
    collection do
      post :webdav_connect
      get :webdav_test
      post :enable_auto_backup
      post :disable_auto_backup
    end
    member do
      get :download
      post :restore
      post :webdav_upload
    end
  end
  get "/webdav/download", to: "backups#webdav_download", as: :webdav_download_backups

  # Settings routes (integrated: shortcuts, import, backup)
  get "/settings", to: "settings#show", as: :settings
  post "/settings/export", to: "settings#export_transactions", as: :export_transactions
  post "/settings/import", to: "settings#import_transactions", as: :import_transactions
  post "/settings/validate_import", to: "settings#validate_import", as: :validate_import
  post "/settings/backup", to: "settings#create_backup", as: :create_backup
  get "/settings/backup/:name", to: "settings#download_backup", as: :download_settings_backup
  post "/settings/clear_data", to: "settings#clear_all_data", as: :clear_all_data
  post "/settings/shortcuts", to: "settings#update_shortcuts", as: :update_shortcuts
  post "/settings/shortcuts/reset", to: "settings#reset_shortcuts", as: :reset_shortcuts

  get "/reports", to: "reports#show", as: :reports
  get "/reports/:year", to: "reports#show", as: :report_year
  get "/reports/:year/:month", to: "reports#show", as: :report_month
  get "/dashboard", to: "dashboard#show", as: :dashboard

  namespace :api do
    namespace :external do
      get :health
      get :context
      post :transactions
    end
    get "currency/rates", to: "currency#rates"
    post "vitals", to: "vitals#create"
  end
end

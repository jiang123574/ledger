Rails.application.routes.draw do
  # Authentication
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  # PWA manifest
  get "manifest" => "pwa#manifest", as: :pwa_manifest
  get "manifest.json" => "pwa#manifest"

  get "up" => "rails/health#show", as: :rails_health_check

  root "accounts#index"

  resources :transactions, only: [ :index, :create, :edit, :update, :destroy ] do
    collection do
      post :bulk_destroy
    end
  end

  resources :entries, only: [ :index, :create, :update, :destroy ] do
    collection do
      post :bulk_destroy
    end
    member do
      get :versions
    end
  end

  resources :versions, only: [ :index, :show ] do
    member do
      post :revert
    end
  end

  resources :accounts do
    member do
      get :versions
      get :bills
      get :bills_entries
      patch :reorder_entries
    end
    post "bill_statements", to: "accounts/bill_statements#create", as: :create_bill_statement
    collection do
      get :stats
      get :entries
    end
    member do
      patch :reorder
    end
  end
  resources :categories, only: [ :create, :update, :destroy ]
  resources :tags, only: [ :index, :create, :update, :destroy ]
  resources :counterparties, only: [ :create, :update, :destroy ]
  resources :budgets, only: [ :index, :create, :update, :destroy ] do
    member do
      get :data
    end
  end
  # 单次预算功能已合并到预算管理 /budgets
  get "single_budgets" => redirect("/budgets", status: 301)
  resources :single_budgets, only: [ :create, :update, :destroy ] do
    patch :start
    patch :complete
    patch :cancel
    resources :budget_items, only: [ :create, :update, :destroy ]
  end
  resources :plans, only: [ :index, :show, :create, :update, :destroy ] do
    member do
      post :execute
    end
  end
  resources :receivables, only: [ :index, :show, :create, :update, :destroy ] do
    member do
      get :settle
      post :settle
      post :revert
    end
  end
  resources :payables, only: [ :index, :show, :create, :update, :destroy ] do
    member do
      get :settle
      post :settle
      post :revert
    end
  end
  resources :recurring, controller: "recurring", only: [ :index, :create, :update, :destroy ] do
    member do
      post :execute
    end
  end

  resources :imports, only: [ :new, :create ] do
    collection do
      post :preview
      get :templates
      get :pixiu
      post :pixiu_upload
      post :pixiu_confirm
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

  # Settings routes
  get "/settings", to: "settings#show", as: :settings
  get "/settings/general", to: "settings#show", as: :settings_general
  get "/settings/currencies", to: "settings#show", as: :settings_currencies
  get "/settings/data", to: "settings#show", as: :settings_data
  get "/settings/shortcuts", to: "settings#show", as: :settings_shortcuts
  get "/settings/danger", to: "settings#show", as: :settings_danger

  # Settings actions
  post "/settings/export", to: "settings#export_transactions", as: :export_transactions
  post "/settings/import", to: "settings#import_transactions", as: :import_transactions
  post "/settings/validate_import", to: "settings#validate_import", as: :validate_import
  post "/settings/backup", to: "settings#create_backup", as: :create_backup
  post "/settings/restore_upload", to: "settings#restore_upload", as: :restore_upload_settings_backup
  get "/settings/backup/:name", to: "settings#download_backup", as: :download_settings_backup, constraints: { name: /[^\/]+/ }
  post "/settings/clear_data", to: "settings#clear_all_data", as: :clear_all_data
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

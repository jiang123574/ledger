Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#show"

  resources :transactions
  resources :accounts
  resources :categories
  resources :budgets, only: [:index, :create, :update, :destroy]
  resources :plans
  resources :recurring, controller: "recurring", only: [:index, :new, :create, :edit, :update, :destroy] do
    member do
      post :execute
    end
  end
  resources :settings, only: [:show, :update]
  get "/settings", to: "settings#show", as: :settings

  get "/reports", to: "reports#show", as: :reports
  get "/dashboard", to: "dashboard#show", as: :dashboard

  namespace :api do
    namespace :external do
      get :health
      get :context
      post :transactions
    end
    get "currency/rates", to: "currency#rates"
  end
end

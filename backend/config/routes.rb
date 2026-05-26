Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :transactions, only: [:index]

      resources :issuers, param: :ticker, constraints: { ticker: /[^\/]+/ }, only: [:show] do
        member do
          get :transactions
          get :trade_events
          get :ohlcv
        end
      end

      get '/insider_sentiment', to: 'transactions#insider_sentiment'

      namespace :market do
        get :indices
        get :sectors
        get :movers
      end

      resources :nature_of_transactions, only: [:index]
      resources :insiders,               only: [:index]

      namespace :imports do
        post "/",        to: "transactions#create", as: :transactions
        post "/issuers", to: "issuers#create",      as: :issuers
      end
    end
  end
end

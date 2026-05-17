Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :transactions, only: [:index]

      resources :issuers, param: :ticker, only: [:show] do
        member do
          get :transactions
        end
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

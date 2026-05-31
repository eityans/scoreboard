Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, defaults: { format: "json" }
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :groups, only: [ :index, :show, :new, :create, :edit, :update ] do
    resources :poker_sessions
    resources :players, only: [ :index, :new, :create, :destroy ]
    resource :leaderboard, only: [ :show ]
  end

  resources :invitations, only: [ :show ], param: :token

  root "dashboard#show"
end

Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  get "up" => "rails/health#show", as: :rails_health_check

  resources :groups, only: [ :index, :show, :new, :create ] do
    resources :poker_sessions
    resources :players, only: [ :index, :new, :create ]
    resource :leaderboard, only: [ :show ]
  end

  resources :invitations, only: [ :show ], param: :token

  root "dashboard#show"
end

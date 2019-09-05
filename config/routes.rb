# frozen_string_literal: true

Rails.application.routes.draw do
  use_doorkeeper scope: 'api/v1' do
    skip_controllers :token_info
    controllers tokens: 'api/v1/custom_tokens'
  end

  apipie

  namespace :cms do
    root to: 'application#index'
    resources :posts
  end

  devise_for :admin_users,
             path: '',
             path_names: {
               sign_in: 'cms/login'
             }

  scope '/api' do
    scope '/v1' do
      # duplicate paths to doorkeeper that is exposed on apipie
      # front end will use this for pretty purpose
      post '/login', to: 'api/v1/custom_tokens#create'
      get '/token', to: 'api/v1/custom_token_info#show'

      # TODO update password
      devise_for :users,
                 path: '',
                 path_names: {
                   account_update: 'update'
                 },
                 controllers: {
                   registrations: 'user_registrations'
                 },
                 defaults: { format: :json }
    end
  end

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end

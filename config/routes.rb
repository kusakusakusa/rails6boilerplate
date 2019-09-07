# frozen_string_literal: true

Rails.application.routes.draw do
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

  devise_for :users, skip: :all

  namespace 'api' do
    namespace 'v1' do
      # duplicate paths to doorkeeper that is exposed on apipie
      # front end will use this for pretty purpose
      post 'user/login', to: 'tokens#login'
      post 'user/refresh', to: 'tokens#refresh'
      post 'user/logout', to: 'tokens#revoke'

      as :user do
        post 'user/account', to: 'accounts#create'
        get 'user/confirm', to: 'confirmations#create'
        post 'user/confirm', to: 'confirmations#show'
        get 'user/forgot-password', to: 'passwords#create'
        post 'user/reset-password', to: 'passwords#update'
      end

      resources :posts, only: [:index], defaults: { format: :json }
    end
  end

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end

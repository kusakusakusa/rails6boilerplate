# frozen_string_literal: true

Rails.application.routes.draw do
  apipie

  namespace :cms do
    root to: 'application#index'
    resources :posts
  end

  devise_scope :admin_users do
    scope 'cms' do
      devise_for :admin_users,
               path: ''
      as :admin_user do
        get 'admin_user' => 'admin_users_devise/registrations#edit'
        get 'admin_user/edit' => 'admin_users_devise/registrations#edit', as: 'edit_admin_user_registration'
        patch 'admin_user' => 'admin_users_devise/registrations#update', as: 'admin_user_registration'
      end
    end
  end

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

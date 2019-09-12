# frozen_string_literal: true

Rails.application.routes.draw do
  mount Ckeditor::Engine => '/ckeditor'
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
      post 'login', to: 'tokens#login'
      post 'refresh', to: 'tokens#refresh'
      post 'logout', to: 'tokens#revoke'

      as :user do
        post 'register', to: 'accounts#create'
        post 'resend-confirmation', to: 'confirmations#create'
        post 'confirm', to: 'confirmations#show'
        post 'forgot-password', to: 'passwords#create'
        post 'reset-password', to: 'passwords#update'
      end

      resources :posts, only: [:index], defaults: { format: :json }
    end
  end

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end

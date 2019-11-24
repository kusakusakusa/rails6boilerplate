# frozen_string_literal: true

Rails.application.routes.draw do
  mount Ckeditor::Engine => '/ckeditor'
  apipie

  get '/healthcheck', to: 'application#healthcheck'

  unless Rails.env.production?
    get '/log-test', to: 'application#log_test'
  end

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
      # devise related
      post 'register', to: 'users#register'
      post 'resend-confirmation', to: 'users#resend_confirmation'
      post 'confirm', to: 'users#confirm'
      post 'forgot-password', to: 'users#forgot_password'
      post 'reset-password', to: 'users#reset_password'

      # duplicate paths to doorkeeper that is exposed on apipie
      # front end will use this for pretty purpose
      post 'login', to: 'tokens#login'
      post 'refresh', to: 'tokens#refresh'
      post 'logout', to: 'tokens#revoke'

      resources :posts, only: [:index], defaults: { format: :json }

      # users
      post 'update-profile', to: 'users#update_profile'
    end
  end

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end

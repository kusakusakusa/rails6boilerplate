# frozen_string_literal: true

Rails.application.routes.draw do
  mount Ckeditor::Engine => '/ckeditor'
  apipie

  get '/healthcheck', to: 'application#healthcheck'

  unless Rails.env.production?
    get '/log-test', to: 'application#log_test'
  end

  root to: 'application#homepage'

  namespace :cms do
    root to: 'application#index'
    resources :hygiene_pages, only: %i[edit update]
    resources :samples
  end

  devise_for :admin_users, skip: [:registrations]
  as :admin_user do
    get 'admin_users/edit', to: 'devise/registrations#edit', as: 'edit_admin_user_registration'
    patch 'admin_users', to: 'devise/registrations#update', as: 'admin_user_registration'
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

      resources :samples, only: [:index], defaults: { format: :json }

      # users
      post 'update-profile', to: 'users#update_profile'
    end
  end

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end

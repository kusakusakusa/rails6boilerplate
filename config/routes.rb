# frozen_string_literal: true

Rails.application.routes.draw do
  use_doorkeeper
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
      devise_for :users,
                 path: '',
                 path_names: {
                   sign_in: 'user/login',
                   sign_out: 'user/logout',
                   registration: 'user/signup',
                   account_update: 'user/update'
                 },
                 controllers: {
                   sessions: 'user_sessions',
                   registrations: 'user_registrations'
                 },
                 defaults: { format: :json }
    end
  end

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end

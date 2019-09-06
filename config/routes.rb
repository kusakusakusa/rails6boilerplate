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

  # full list of devise path:
  # sign_in:
  # sign_out:
  # password:
  # confirmation:
  # registration:
  # edit:

  scope '/api' do
    scope '/v1' do
      # TODO update password
      devise_for :users,
                 only: %i[registrations password confirmation],
                 path: '',
                 path_names: {
                  registration: 'register'
                 },
                 controllers: {
                   registrations: 'api/v1/user_registrations'
                 },
                 defaults: { format: :json }
    end
  end

  namespace 'api' do
    namespace 'v1' do
      # duplicate paths to doorkeeper that is exposed on apipie
      # front end will use this for pretty purpose
      post 'login', to: 'tokens#create'
      post 'refresh', to: 'tokens#refresh'

      resources :posts, only: [:index], defaults: { format: :json }
    end
  end

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end

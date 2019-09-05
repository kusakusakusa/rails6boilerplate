# frozen_string_literal: true

module Api
  module V1
    class TokensController < Doorkeeper::TokensController
      resource_description do
        name 'Sessions'
        resource_id 'Sessions'
        api_versions 'v1' # , 'v2'
      end

      api :POST, '/login', 'Return JWT access_token and refresh_token'
      description 'Returns JWT access_token and refresh_token'
      param :email, URI::MailTo::EMAIL_REGEXP, required: true
      param :password, String, desc: "Length #{Devise.password_length.to_a.first} to #{Devise.password_length.to_a.last}", required: true
      param :grant_type, %w[password], required: true
      def create
        super
      end

      api :POST, '/refresh', 'Return JWT refresh_token'
      description 'Returns JWT refresh_token'
      param :refresh_token, String, desc: 'refresh_token to get new access_token'
      param :refresh_token, String, desc: 'refresh_token to get new access_token'
      param :grant_type, %w[refresh_token], required: true
      def refresh
        # essentially same method as create
        # but differentiating it for better api documentation
        create
      end
    end
  end
end

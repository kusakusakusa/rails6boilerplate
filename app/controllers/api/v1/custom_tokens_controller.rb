# frozen_string_literal: true

module Api
  module V1
    class CustomTokensController < Doorkeeper::TokensController
      resource_description do
        name 'Sessions'
        resource_id 'Sessions'
        api_versions 'v1' # , 'v2'
      end

      api :POST, '/login', 'Return JWT'
      description 'Returns JWT token in Authorization header.'
      param :email, URI::MailTo::EMAIL_REGEXP, required: true
      param :password, String, required: true, desc: "Length #{Devise.password_length.to_a.first} to #{Devise.password_length.to_a.last}"
      param :grant_type, String, required: true
      def create
        super
      end
    end
  end
end

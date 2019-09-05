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

#### OVERWRITE ####
# need add `response_code` and `response_message` to response for standardization

module Doorkeeper
  module OAuth
    class ErrorResponse
      # overwrite, do not use default error and error_description key
      def body
        {
          response_code: name,
          response_message: description,
          state: state
        }
      end
    end
  end
end

module Doorkeeper
  module OAuth
    class TokenResponse
      def body
        {
          # copied
          "access_token" => token.plaintext_token,
          "token_type" => token.token_type,
          "expires_in" => token.expires_in_seconds,
          "refresh_token" => token.plaintext_refresh_token,
          "scope" => token.scopes_string,
          "created_at" => token.created_at.to_i,
          # custom
          response_code: 'custom.success.default',
          response_message: I18n.t('custom.success.default')
        }.reject { |_, value| value.blank? }
      end
    end
  end
end

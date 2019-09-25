# frozen_string_literal: true

module Api
  class BaseController < ActionController::API
    include ApiRescues

    before_action :add_default_response_keys
    before_action :doorkeeper_authorize!

    protected

    def doorkeeper_unauthorized_render_options(error: nil)
      if error.nil?
        {
          json: {
            response_code: 'custom.errors.doorkeeper_unauthorized_nil',
            response_message: doorkeeper_unauthorized_default_message
          }
        }
      else
        {
          json: {
            response_code: "doorkeeper.errors.messages.#{error.name}.#{error.reason}",
            response_message: error.try(:description) || doorkeeper_unauthorized_default_message
          }
        }
      end
    end

    private

    def current_user
      @current_user ||= if doorkeeper_token
                          User.find(doorkeeper_token.resource_owner_id)
                        else
                          warden.authenticate(scope: :user)
                        end
    end

    def doorkeeper_unauthorized_default_message
      if Rails.env.production?
        I18n.t('custom.errors.doorkeeper_unauthorized_nil')
      else
        "#{I18n.t('custom.errors.doorkeeper_unauthorized_nil')} - this should not happen, please alert backend"
      end
    end

    def add_default_response_keys
      @response_code ||= 'custom.success.default'
      @response_message ||= I18n.t('custom.success.default')
    end

    def handle_doorkeeper_errors exception
      case exception
      when Doorkeeper::Errors::TokenExpired
        @response_code = 'doorkeeper.errors.messages.invalid_token.expired'
        @response_message = I18n.t(@response_code)
      when Doorkeeper::Errors::TokenRevoked
        @response_code = 'doorkeeper.errors.messages.invalid_token.revoked'
        @response_message = I18n.t(@response_code)
      when Doorkeeper::Errors::TokenUnknown
        @response_code = 'doorkeeper.errors.messages.invalid_token.unknown'
        @response_message = I18n.t(@response_code)

      # TODO how to handle these?
      when Doorkeeper::Errors::InvalidToken, Doorkeeper::Errors::TokenForbidden
        @response_code = 'doorkeeper.errors.messages.invalid_token.unknown'
        @response_message = I18n.t(@response_code)
      end

      render json: {
        response_code: @response_code,
        response_message: @response_message
      }, status: 401
    end
  end
end

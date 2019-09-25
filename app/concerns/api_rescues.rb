# frozen_string_literal: true

module ApiRescues
  extend ActiveSupport::Concern

  included do
    rescue_from Doorkeeper::Errors::InvalidToken, with: :handle_doorkeeper_errors
    rescue_from Doorkeeper::Errors::TokenForbidden, with: :handle_doorkeeper_errors
    rescue_from Doorkeeper::Errors::TokenExpired, with: :handle_doorkeeper_errors
    rescue_from Doorkeeper::Errors::TokenRevoked, with: :handle_doorkeeper_errors
    rescue_from Doorkeeper::Errors::TokenUnknown, with: :handle_doorkeeper_errors

    rescue_from Apipie::ParamMissing do |e|
      render json: {
        response_code: 'custom.errors.apipie.missing_params',
        response_message: e.message
      }, status: 400
    end

    rescue_from Apipie::ParamInvalid do |e|
      render json: {
        response_code: 'custom.errors.apipie.params_invalid',
        response_message: e.message
      }, status: 400
    end
  end
end
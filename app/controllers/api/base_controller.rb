# frozen_string_literal: true

module Api
  class BaseController < ActionController::API
    before_action :add_default_response_keys

    protected

    def doorkeeper_unauthorized_render_options(error: nil)
      if error.nil?
        {
          json: {
            response_code: 'custom.errors.doorkeeper_unauthorized_nil',
            response_message: default_message
          }
        }
      else
        {
          json: {
            response_code: "doorkeeper.errors.messages.#{error.name}.#{error.reason}",
            response_message: error.try(:description) || default_message
          }
        }
      end
    end

    private

    def default_message
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
  end
end

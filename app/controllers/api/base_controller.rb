# frozen_string_literal: true

module Api
  class BaseController < ActionController::API
    include ApiRescues

    before_action :add_default_response_keys
    before_action :doorkeeper_authorize!

    private

    def current_user
      @current_user ||= if doorkeeper_token
                          User.find(doorkeeper_token.resource_owner_id)
                        else
                          warden.authenticate(scope: :user, store: false)
                        end
    end
  end
end

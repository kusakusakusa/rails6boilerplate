# frozen_string_literal: true

module Cms
  class BaseController < ActionController::Base
    before_action :redirect_user
    before_action :authenticate_admin_user!

    rescue_from Exception, with: :catch_all

    layout 'cms'

    private

    def redirect_user
      if user_signed_in?
        flash[:danger] = I18n.t('devise.failure.unauthorized')
        redirect_to root_path
      end
    end

    def catch_all exception
      flash[:danger] = exception.message
      redirect_back(fallback_location: cms_root_path)
    end
  end
end

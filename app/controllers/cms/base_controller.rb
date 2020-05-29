# frozen_string_literal: true

module Cms
  class BaseController < ActionController::Base
    before_action :redirect_user
    before_action :authenticate_admin_user!

    layout 'cms'

    private

    def redirect_user
      if user_signed_in?
        flash[:danger] = I18n.t('devise.failure.unauthorized')
        redirect_to root_path
      end
    end
  end
end

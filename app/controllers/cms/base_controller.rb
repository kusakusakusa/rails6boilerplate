module Cms
  class BaseController < ActionController::Base
    before_action :authenticate_admin_user!

    layout 'cms'
  end
end

# frozen_string_literal: true

class ApplicationController < ActionController::Base
  layout :layout_by_resource

  private

  def layout_by_resource
    if devise_controller?
      if resource_name == :admin_user &&
        controller_name == 'registrations'
        # update account pages should use cms template
        'cms'
      else
        'devise'
      end
    else
      'application'
    end
  end

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || cms_root_path
  end

  def after_sign_out_path_for(resource_or_scope)
    cms_root_path
  end
end

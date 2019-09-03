# frozen_string_literal: true

class ApplicationController < ActionController::Base
  private

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || cms_root_path
  end

  def after_sign_out_path_for(resource_or_scope)
    cms_root_path
  end
end

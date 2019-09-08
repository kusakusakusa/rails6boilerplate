# frozen_string_literal: true

module AdminUsersDevise
  class RegistrationsController < Devise::RegistrationsController
    protected

    def after_update_path_for(resource)
      stored_location_for(resource) || cms_root_path
    end
  end
end

# frozen_string_literal: true

module Api
  module V1
    class UsersController < Api::BaseController
      before_action :add_default_response_keys

      resource_description do
        name 'Users'
        resource_id 'Users'
        api_versions 'v1' # , 'v2'
      end

      api :POST, '/update-profile', 'Update profile'
      description 'Update profile'
      header 'Authorization', 'Bearer [your_access_token]', required: true
      param :first_name, String
      param :last_name, String
      def update_profile
        current_user.attributes = udpate_profile_params
        current_user.save
        unless current_user.errors.empty?
          @response_code = 'custom.errors.users.update_profile'
          @response_message = current_user.errors.full_messages.to_sentence
        end
      end

      private

      def udpate_profile_params
        params.fetch(:user, {}).permit(:first_name,:last_name)
      end
    end
  end
end

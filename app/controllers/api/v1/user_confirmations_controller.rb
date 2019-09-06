# frozen_string_literal: true

module Api
  module V1
    class UserConfirmationsController < Devise::ConfirmationsController
      # TODO add to all custom Devise controllers
      before_action :add_default_response_keys

      resource_description do
        name 'Accounts'
        resource_id 'Accounts'
        api_versions 'v1' # , 'v2'
      end
      respond_to :json
      skip_before_action :verify_authenticity_token

      api :GET, '/confirm', 'Confirm user with token sent to their email'
      description 'Confirm user with token sent to their email'
      param :confirmation_token, String, desc: 'Confirmation token sent to email'
      def show
        self.resource = resource_class.confirm_by_token(params[:confirmation_token])
        yield resource if block_given?

        if resource.errors.empty?
          ### START overwrite ###
          # set_flash_message!(:notice, :confirmed)
          # respond_with_navigational(resource){ redirect_to after_confirmation_path_for(resource_name, resource) }
          ### END overwrite ###
        else
          ### START overwrite ###
          # respond_with_navigational(resource.errors, status: :unprocessable_entity){ render :new }
          ### END overwrite ###
        end
      end

      private

      def add_default_response_keys
        @response_code ||= 'custom.success.default'
        @response_message ||= I18n.t('custom.success.default')
      end
    end
  end
end

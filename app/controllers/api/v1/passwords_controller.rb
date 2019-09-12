# frozen_string_literal: true

module Api
  module V1
    class PasswordsController < Devise::PasswordsController
      before_action :add_default_response_keys

      resource_description do
        name 'Passwords'
        resource_id 'Passwords'
        api_versions 'v1' # , 'v2'
      end
      respond_to :json
      skip_before_action :verify_authenticity_token

      api :POST, '/forgot-password', 'Send reset passsword email'
      description 'Send reset passsword email'
      param :email, URI::MailTo::EMAIL_REGEXP, required: true
      def create
        ### START overwrite ###
        # self.resource = resource_class.send_reset_password_instructions(resource_params)
        self.resource = resource_class.send_reset_password_instructions({ email: params[:email] })
        ### END overwrite ###
        yield resource if block_given?

        if successfully_sent?(resource)
          ### START overwrite ###
          # respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name))

          render status: 200
          ### END overwrite ###
        else
          ### START overwrite ###
          # respond_with(resource)

          @response_code = 'custom.errors.devise.passwords'
          @response_message = resource.errors.full_messages.to_sentence
          render status: 400
          ### END overwrite ###
        end
      end

      api :POST, '/reset-password', 'Reset user password'
      description 'Reset user password'
      param :reset_password_token, String, desc: 'Reset password token received from email', required: true
      param :password, String, desc: 'New password', required: true
      def update
        ### START overwrite ###
        # self.resource = resource_class.reset_password_by_token(resource_params)
        self.resource = resource_class.reset_password_by_token({
          reset_password_token: params[:reset_password_token],
          password: params[:password],
        })

        # this is custom code as the security bug is mitigated with reconfirmable being false
        resource.confirm
        ### END overwrite ###
        yield resource if block_given?

        if resource.errors.empty?
          resource.unlock_access! if unlockable?(resource)
          if Devise.sign_in_after_reset_password
            # set to false for this boilerplate, should not reach here
            flash_message = resource.active_for_authentication? ? :updated : :updated_not_active
            set_flash_message!(:notice, flash_message)
            resource.after_database_authentication
            sign_in(resource_name, resource)
          else
            ### START overwrite ###
            # set_flash_message!(:notice, :updated_not_active)
            ### END overwrite ###
          end
          ### START overwrite ###
          # respond_with resource, location: after_resetting_password_path_for(resource)
          render status: 200
          ### END overwrite ###
        else
          ### START overwrite ###
          # set_minimum_password_length
          # respond_with resource
          @response_code = 'custom.errors.devise.passwords'
          @response_message = resource.errors.full_messages.to_sentence
          render status: 400
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

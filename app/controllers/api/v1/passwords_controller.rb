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

      api :GET, '/user/forgot-password', 'Send reset passsword email'
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

      api :GET, '/user/reset-password', 'Send reset passsword email'
      description 'Send reset passsword email'
      param :email, URI::MailTo::EMAIL_REGEXP, required: true

      private

      def add_default_response_keys
        @response_code ||= 'custom.success.default'
        @response_message ||= I18n.t('custom.success.default')
      end
    end
  end
end

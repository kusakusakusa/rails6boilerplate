# frozen_string_literal: true

module Api
  module V1
    class ConfirmationsController < Devise::ConfirmationsController
      # TODO add to all custom Devise controllers
      before_action :add_default_response_keys

      resource_description do
        name 'Authentication-confirmations'
        resource_id 'Authentication-confirmations'
        api_versions 'v1' # , 'v2'
      end
      respond_to :json
      skip_before_action :verify_authenticity_token

      api :POST, '/resend-confirmation', 'Resend email'
      description 'Resend confirmation email'
      param :email, URI::MailTo::EMAIL_REGEXP, required: true
      # overwrite devise/confirmations#create
      def resend_confirmation
        ### START overwrite ###
        # self.resource = resource_class.send_confirmation_instructions(resource_params)
        self.resource = resource_class.send_confirmation_instructions({ email: params[:email] })
        ### END overwrite ###
        yield resource if block_given?

        if successfully_sent?(resource)
          ### START overwrite ###
          # respond_with({}, location: after_resending_confirmation_instructions_path_for(resource_name))

          render status: 200
          ### END overwrite ###
        else
          ### START overwrite ###
          # respond_with(resource)

          @response_code = 'custom.errors.devise.confirmations'
          @response_message = resource.errors.full_messages.to_sentence
          render status: 400
          ### END overwrite ###
        end
      end

      api :POST, '/confirm', 'Confirm user with token sent to their email'
      description 'Confirm user with token sent to their email'
      param :confirmation_token, String, desc: 'Confirmation token sent to email', required: true
      # overwrite devise/confirmations#show
      def confirm
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

          @response_code = 'custom.errors.devise.confirmations'
          @response_message = resource.errors.full_messages.to_sentence
          render status: 400
        end
      end

      protected

      def devise_parameter_sanitizer
        # should not happen
        return unless resource_class == User
        params_copy = params.clone
        params_copy.delete :user_registration
        params_copy.delete :format

        # modify the params to add the 'user' key for the ParameterSanitizer to use
        User::ParameterSanitizer.new(User, :user, user: params_copy)
      end

      private

      def add_default_response_keys
        @response_code ||= 'custom.success.default'
        @response_message ||= I18n.t(@response_code)
      end
    end
  end
end

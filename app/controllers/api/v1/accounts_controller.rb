# frozen_string_literal: true

module Api
  module V1
    class AccountsController < Devise::RegistrationsController
      before_action :add_default_response_keys

      resource_description do
        name 'Accounts'
        resource_id 'Accounts'
        api_versions 'v1' # , 'v2'
      end
      respond_to :json
      skip_before_action :verify_authenticity_token

      api :POST, '/register', 'Create account and register. Sends confirmation email'
      description 'Create account and register. Sends confirmation email'
      param :email, URI::MailTo::EMAIL_REGEXP, required: true
      param :password, String, desc: "Length #{Devise.password_length.to_a.first} to #{Devise.password_length.to_a.last}", required: true
      def create
        build_resource(sign_up_params)
        resource.save
        yield resource if block_given?
        if resource.persisted?
          if resource.active_for_authentication?
            # should not reach here upon sign up if :confirmable module enabled
            set_flash_message! :notice, :signed_up
            sign_up(resource_name, resource)
            respond_with resource, location: after_sign_up_path_for(resource)
          else
            set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
            expire_data_after_sign_in!
            ### START overwrite ###
            # respond_with resource, location: after_inactive_sign_up_path_for(resource)
            @response_code = 'devise.confirmations.send_instructions'
            @response_message = I18n.t('devise.confirmations.send_instructions')
            ### END overwrite ###
          end
        else
          clean_up_passwords resource
          set_minimum_password_length
          ### START overwrite ###
          # respond_with resource

          @response_code = 'custom.errors.devise.registrations'
          @response_message = resource.errors.full_messages.to_sentence.capitalize

          render status: 400
          ### END overwrite ###
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
        @response_message ||= I18n.t('custom.success.default')
      end
    end
  end
end

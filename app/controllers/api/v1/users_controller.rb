# frozen_string_literal: true

module Api
  module V1
    class UsersController < Api::BaseController
      before_action :doorkeeper_authorize!, only: %i[
        update_profile
        get_profile
        update_password
      ]

      resource_description do
        name 'Users'
        resource_id 'Users'
        api_versions 'v1' # , 'v2'
      end

      api :POST, '/register', 'Create account and register. Sends confirmation email'
      description 'Create account and register. Sends confirmation email'
      header 'Content-Type', 'application/json'
      header 'Accept', 'application/json'
      param :email, URI::MailTo::EMAIL_REGEXP, required: true
      param :password, String, desc: "Length #{Devise.password_length.to_a.first} to #{Devise.password_length.to_a.last}", required: true
      param :first_name, String, required: true
      param :last_name, String, required: true
      # overwrite devise/registrations#create
      def register
        user = User.new(register_params)
        user.save
        if user.persisted?
          @response_code = 'custom.success.default'
          @response_message = I18n.t('devise.confirmations.send_instructions')
        else
          @response_code = 'custom.errors.devise.registrations'
          @response_message = user.errors.full_messages.to_sentence.capitalize

          render :default, status: 400
        end
      end

      api :POST, '/resend-confirmation', 'Resend email'
      description 'Resend confirmation email'
      header 'Content-Type', 'application/json'
      header 'Accept', 'application/json'
      param :email, URI::MailTo::EMAIL_REGEXP, required: true
      def resend_confirmation
        user = User.send_confirmation_instructions(email: resend_confirmation_params[:email])
        if Devise.paranoid # just send even if not confirmed
          user.errors.clear
          @response_message = I18n.t('devise.confirmations.send_paranoid_instructions')
          render :default, status: 200
        elsif user.errors.empty?
          @response_message = I18n.t('devise.confirmations.send_instructions')
          render :default, status: 200
        else
          @response_code = 'custom.errors.devise.confirmations'
          @response_message = user.errors.full_messages.to_sentence
          render :default, status: 400
        end
      end

      api :POST, '/confirm', 'Confirm user with token sent to their email'
      description 'Confirm user with token sent to their email'
      header 'Content-Type', 'application/json'
      header 'Accept', 'application/json'
      param :confirmation_token, String, desc: 'Confirmation token sent to email', required: true
      def confirm
        user = User.confirm_by_token(confirm_params[:confirmation_token])
        if user.errors.empty?
          render :default, status: 200
        else
          @response_code = 'custom.errors.devise.confirmations'
          @response_message = user.errors.full_messages.to_sentence
          render :default, status: 400
        end
      end

      api :GET, '/get-profile', 'Get profile'
      description 'Get profile'
      header 'Authorization', 'Bearer [your_access_token]', required: true
      header 'Content-Type', 'application/json'
      header 'Accept', 'application/json'
      def get_profile
        current_user # initialize @current_user
        render :update_profile, status: 200
      end

      api :POST, '/update-profile', 'Update profile'
      description 'Update profile'
      header 'Authorization', 'Bearer [your_access_token]', required: true
      header 'Content-Type', 'application/json'
      header 'Accept', 'application/json'
      param :first_name, String
      param :last_name, String
      def update_profile
        current_user.attributes = udpate_profile_params
        current_user.save
        unless current_user.errors.empty?
          @response_code = 'custom.errors.users.update_profile'
          @response_message = current_user.errors.full_messages.to_sentence
          render :default, status: 400 and return
        end
      end

      api :POST, '/update-avatar', 'Update avatar'
      description 'Update avatar'
      param :avatar, String, required: true, desc: 'Base64'
      header 'Authorization', 'Bearer [your_access_token]', required: true
      header 'Content-Type', 'application/json'
      header 'Accept', 'application/json'
      def update_avatar
        begin
          ActiveRecord::Base.transaction do
            current_user.attach_avatar(avatar_params[:avatar])
            current_user.save
            raise ActiveRecord::RecordInvalid.new(current_user) unless current_user.errors.empty?
            render :update_profile, status: 200
          end
        rescue ArgumentError => error
          @response_code = 'custom.errors.users.update_avatar'
          @response_message = error.message
          render :default, status: 400 and return
        rescue ActiveRecord::RecordInvalid => error
          @response_code = 'custom.errors.users.update_avatar'
          @response_message = current_user.errors.full_messages.to_sentence
          render :default, status: 400 and return
        end
      end

      api :POST, '/update-password', 'Update password'
      description 'Update password'
      param :current_password, String, required: true
      param :password, String, required: true
      header 'Authorization', 'Bearer [your_access_token]', required: true
      header 'Content-Type', 'application/json'
      header 'Accept', 'application/json'
      def update_password
        unless current_user.valid_password?(update_password_params[:current_password])
          @response_code = 'custom.errors.users.wrong_current_password'
          @response_message = I18n.t(@response_code)
          render :default, status: 403 and return
        end

        current_user.update(password: update_password_params[:password])
        unless current_user.errors.empty?
          @response_code = 'custom.errors.users.update_password'
          @response_message = current_user.errors.full_messages.to_sentence
          render :default, status: 400 and return
        end

        render :default, status: 200
      end

      api :POST, '/forgot-password', 'Send reset passsword email'
      description 'Send reset passsword email'
      param :email, URI::MailTo::EMAIL_REGEXP, required: true
      # overwrite devise/passwords#create
      def forgot_password
        user = User.send_reset_password_instructions(email: forgot_password_params[:email])

        if Devise.paranoid
          user.errors.clear
          @response_message = I18n.t('devise.passwords.send_paranoid_instructions')

          render :default, status: 200
        elsif user.errors.empty?
          render :default, status: 200
        else
          @response_code = 'custom.errors.devise.passwords'
          @response_message = user.errors.full_messages.to_sentence
          render :default, status: 400
        end
      end

      api :POST, '/reset-password', 'Reset user password'
      description 'Reset user password'
      param :reset_password_token, String, desc: 'Reset password token received from email', required: true
      param :password, String, desc: 'New password', required: true
      # overwrite devise/passwords#update
      def reset_password
        user = User.reset_password_by_token(
          reset_password_token: reset_password_params[:reset_password_token],
          password: reset_password_params[:password]
        )

        # this is custom code as the security bug is mitigated with reconfirmable being false
        user.confirm

        if user.errors.empty?
          # TODO check implementation of unlockable?
          # ignore scenario:
          # user.unlock_access! if unlockable?(user)

          # Devise.sign_in_after_reset_password is set to false
          # so ignore scenario

          render :default, status: 200
        else
          @response_code = 'custom.errors.devise.passwords'
          @response_message = user.errors.full_messages.to_sentence
          render :default, status: 400
        end
      end

      private

      def udpate_profile_params
        params.permit(
          :first_name,
          :last_name
        )
      end

      def avatar_params
        params.permit(
          :avatar
        )
      end

      def register_params
        params.permit(
          :email,
          :password,
          :first_name,
          :last_name
        )
      end

      def reset_password_params
        params.permit(
          :reset_password_token,
          :password
        )
      end

      def forgot_password_params
        params.permit(
          :email
        )
      end

      def confirm_params
        params.permit(
          :confirmation_token
        )
      end

      def resend_confirmation_params
        params.permit(
          :email
        )
      end

      def update_password_params
        params.permit(
          :password,
          :current_password
        )
      end
    end
  end
end

# frozen_string_literal: true

module Contactable
  extend ActiveSupport::Concern

  include Loggable

  included do
    skip_before_action :doorkeeper_authorize!, only: :contact_form
    before_action :get_recaptcha_score, only: :contact_form
  end

  def contact_form
    if @score > Rails.application.config.recaptcha_threshold[:spam]
      begin
        ApplicationMailer.contact(
          name: contact_params[:name],
          email: contact_params[:email],
          subject: contact_params[:subject],
          message: contact_params[:message],
        ).deliver_now
      rescue Exception => e
        puts e.message
        render json: {
          message: 'Error in sending message. Please refresh and try again.'
        }, status: 500 and return
      end
    end

    render json: {
      message: 'Successfully sent.'
    }, status: 200 and return
  end

  private

  def contact_params
    params.require(:contact).permit(
      :name,
      :email,
      :subject,
      :message,
    )
  end

  def get_recaptcha_score
    response = RestClient.post(
      'https://www.google.com/recaptcha/api/siteverify',
      {
        secret: Rails.application.credentials.dig(Rails.env.to_sym, :recaptcha, :secret_key),
        response: recaptcha_token_param[:recaptcha_token]
      }
    )

    result = JSON.parse(response.body)
    unless result['success']
      p "Error: #{result.inspect}"
      log(message: "[Fail] recaptcha result: #{result.inspect}", log_level: :info, stream: 'recaptcha')

      render json: {
        message: 'Error in sending message. Please refresh and try again.'
      }, status: 500 and return
    end

    @score = JSON.parse(response.body)['score']
  end

  def recaptcha_token_param
    params.permit(
      :recaptcha_token
    )
  end
end

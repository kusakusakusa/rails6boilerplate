# frozen_string_literal: true

class TemporaryPasswordMailer < ApplicationMailer
  def send_email(email:, password:)
    @password = password
    mail(
      to: email,
      subject: '[Rails6boilerplate] Temporary Password',
      from: "Rails6boilerplate <#{Rails.application.credentials.dig(Rails.env.to_sym, :action_mailer, :default, :from)}>"
    )
  end
end

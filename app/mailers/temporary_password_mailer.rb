# frozen_string_literal: true

class TemporaryPasswordMailer < ApplicationMailer
  def send_email(email:, password:)
    @password = password
    mail(
      to: email,
      subject: '[Rails6boilerplate] Temporary Password',
      from: %("Rails6boilerplate" <no-reply@TBC.com>)
    )
  end
end

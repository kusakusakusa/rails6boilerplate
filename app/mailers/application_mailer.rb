# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  include WithPdf

  layout 'mailer'

  def sample_pdf sample
    attachments['sample.pdf'] = generate_pdf(sample)
    mail(
      subject: 'Sample PDF',
      to: 'sample@mailinator.com',
      from: 'sample@mailinator.com',
    )
  end

  def contact name:, email:, subject:, message:
    @name = name
    @email = email
    @subject = subject
    @message = message

    mail(
      subject: "[Contact] #{subject}",
      to: Rails.application.credentials.dig(Rails.env.to_sym, :action_mailer, :default, :to),
      from: Rails.application.credentials.dig(Rails.env.to_sym, :action_mailer, :default, :from),
    )
  end

  def send_temporary_password_email user
    # Content needs to change if its an API environment where the login method is different
    @user = user
    mail(
      subject: "Your account has been created",
      to: user.email,
      from: Rails.application.credentials.dig(Rails.env.to_sym, :action_mailer, :default, :from),
    )
  end
end

# frozen_string_literal: true

module Contactable
  extend ActiveSupport::Concern

  def contact_form
    ApplicationMailer.contact(
      name: contact_params[:name],
      email: contact_params[:email],
      subject: contact_params[:subject],
      message: contact_params[:message],
    ).deliver_now

    flash[:success] = "Successfully sent!"
    redirect_back(fallback_location: root_path)
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
end

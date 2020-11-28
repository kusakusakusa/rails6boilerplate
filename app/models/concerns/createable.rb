# frozen_string_literal: true

# this module is for requirement where the user need to be able to be added in cms
module Createable
  extend ActiveSupport::Concern

  included do
    before_update :update_temporary_password, if: :will_save_change_to_encrypted_password?
  end

  class_methods do
    def create_with_temporary_password! other_attributes
      resource = self.new(other_attributes)
      resource.skip_confirmation!
      resource.password = resource.temp_password
      resource.on_temporary_password = true
      resource.send("#{resource.temporary_password_change_flag}=", true)
      resource.save!
      ApplicationMailer.send_temporary_password_email(resource).deliver_now
      resource
    end
  end

  def on_temporary_password?
    send(temporary_password_change_flag)
  end

  def temp_password
    "#{Digest::MD5.hexdigest("#{email}#{Rails.env}")}"
  end

  def temporary_password_change_flag
    "on_temporary_password"
  end

  private

  def update_temporary_password
    if on_temporary_password?
      self.send("#{temporary_password_change_flag}=", false)
    end
  end
end

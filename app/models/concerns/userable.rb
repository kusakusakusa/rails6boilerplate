# frozen_string_literal: true

require 'active_support/concern'

module Userable
  extend ActiveSupport::Concern

  included do
    validates :first_name,
              :last_name,
              :email,
              presence: true
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def full_title
    "#{full_name} (#{email})"
  end

  def json_attributes
    custom_attributes = super
    custom_attributes.delete 'encrypted_password'
    custom_attributes.delete 'reset_password_token'
    custom_attributes.delete 'reset_password_sent_at'
    custom_attributes.delete 'remember_created_at'
    custom_attributes.delete 'confirmation_token'
    custom_attributes.delete 'confirmed_at'
    custom_attributes.delete 'confirmation_sent_at'
    custom_attributes
  end
end

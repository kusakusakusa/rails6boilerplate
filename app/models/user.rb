# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :confirmable,
         :validatable

  has_many :access_grants,
           class_name: 'Doorkeeper::AccessGrant',
           foreign_key: :resource_owner_id,
           dependent: :delete_all # or :destroy if you need callbacks

  has_many :access_tokens,
           class_name: 'Doorkeeper::AccessToken',
           foreign_key: :resource_owner_id,
           dependent: :delete_all # or :destroy if you need callbacks

  has_many :posts

  protected

  # overwrite devise confirmation_token generation
  # use confirmation_token as the inpupt code
  def generate_confirmation_token
    if self.confirmation_token && !confirmation_period_expired?
      @raw_confirmation_token = self.confirmation_token
    else
      ### START overwrite ###
      # self.confirmation_token = @raw_confirmation_token = Devise.friendly_token
      ### END overwrite ###

      # ensure unique confirmation_token
      loop do
        self.confirmation_token = @raw_confirmation_token = SecureRandom.alphanumeric(Rails.configuration.confirmation_token_length)
      break if !self.class.exists?(confirmation_token: self.confirmation_token)
      end

      self.confirmation_sent_at = Time.now.utc
    end
  end
end

class User::ParameterSanitizer < Devise::ParameterSanitizer
  def initialize(*)
    super
  end
end

# frozen_string_literal: true

module Doorkeepable
  extend ActiveSupport::Concern

  included do
    has_many :access_grants,
             class_name: 'Doorkeeper::AccessGrant',
             foreign_key: :resource_owner_id,
             dependent: :delete_all # or :destroy if you need callbacks

    has_many :access_tokens,
             class_name: 'Doorkeeper::AccessToken',
             foreign_key: :resource_owner_id,
             dependent: :delete_all # or :destroy if you need callbacks
  end

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

  # overwrite devise confirmation_token generation
  # for users to receive simpler password reset code
  def set_reset_password_token
    ### START overwrite ###
    # raw, enc = Devise.token_generator.generate(self.class, :reset_password_token)
    raw, enc = Devise.token_generator.custom_generate(self.class, :reset_password_token)
    ### END overwrite ###

    self.reset_password_token   = enc
    self.reset_password_sent_at = Time.now.utc
    save(validate: false)
    raw
  end
end

# frozen_string_literal: true

require 'active_support/concern'

module Avatarable
  extend ActiveSupport::Concern

  included do
    has_one_attached :avatar
    validates :avatar,
              content_type: Rails.application.config.image_types
  end

  def attach_avatar base64
    base64_data = base64.split_base64

    raise ArgumentError.new('no extension') if base64_data.extension.nil?

    data_blob = Base64.strict_decode64(base64_data.data)
    avatar.attach(
      io: StringIO.new(data_blob),
      filename: "#{self.class.name}-avatar.#{base64_data.extension}"
    )
  end

  def json_attributes
    custom_attributes = super

    if avatar.attached?
      custom_attributes[:avatar] = Rails.env.test? ? 'http://localhost:3333' : Rails.application.routes.url_helpers.rails_blob_url(avatar, host: Rails.application.credentials.dig(Rails.env.to_sym, :action_mailer, :asset_host))
    else
      custom_attributes[:avatar] = nil
    end

    custom_attributes
  end
end

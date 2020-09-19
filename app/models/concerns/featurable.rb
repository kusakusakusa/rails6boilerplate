# frozen_string_literal: true

module Featurable
  extend ActiveSupport::Concern

  included do
    scope :featured, -> { where(featured: true) }
    has_one_attached :featured_image

    validates :featured_image,
              attached: true,
              content_type: Rails.application.config.image_types
  end
end

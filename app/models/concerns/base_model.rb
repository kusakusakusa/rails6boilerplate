# frozen_string_literal: true

module BaseModel
  extend ActiveSupport::Concern

  included do
    scope :featured, -> { where(featured: true) }
  end

  def json_attributes
    attributes.clone
  end
end

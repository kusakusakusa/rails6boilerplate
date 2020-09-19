# frozen_string_literal: true

module BaseModel
  extend ActiveSupport::Concern

  def json_attributes
    attributes.clone
  end
end

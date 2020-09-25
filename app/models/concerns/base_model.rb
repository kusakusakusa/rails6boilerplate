# frozen_string_literal: true

module BaseModel
  extend ActiveSupport::Concern

  def json_attributes
    attributes.clone
  end

  def print_errors
    if errors.empty?
      'No errors'
    else
      print_errors
    end
  end
end

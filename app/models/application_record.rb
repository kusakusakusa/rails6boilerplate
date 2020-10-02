# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def json_attributes
    attributes.clone
  end

  def print_errors
    if errors.empty?
      'No errors'
    else
      errors.full_messages.to_sentence
    end
  end
end

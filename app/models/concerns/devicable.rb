# frozen_string_literal: true

module Devicable
  extend ActiveSupport::Concern

  included do |klass|
    has_many :devices, inverse_of: klass.name.downcase.to_sym
  end
end

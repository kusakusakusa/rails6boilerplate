# frozen_string_literal: true

module Devicable
  extend ActiveSupport::Concern

  included do |klass|
    has_many :devices, inverse_of: klass.name.underscore.to_sym
  end
end

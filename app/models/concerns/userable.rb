# frozen_string_literal: true

require 'active_support/concern'

module Userable
  extend ActiveSupport::Concern

  included do
    validates :first_name,
              :last_name,
              :email,
              presence: true
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def full_title
    "#{full_name} (#{email})"
  end
end

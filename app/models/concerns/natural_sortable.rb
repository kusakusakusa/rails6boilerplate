# frozen_string_literal: true

require 'active_support/concern'

module NaturalSortable
  extend ActiveSupport::Concern

  included do
    scope :naturally_sorted, -> (key) { sort_by{ |record| NaturalSort(record.send(key)) } }
  end
end

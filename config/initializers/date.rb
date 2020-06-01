# frozen_string_literal: true

# TODO test

class Date
  def display
    self&.strftime('%b %d, %Y') || '-'
  end
end

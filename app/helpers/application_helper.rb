# frozen_string_literal: true

module ApplicationHelper
  def flash_class key
    case key
    when 'alert'
      'alert-danger'
    when 'notice'
      'alert-warning'
    else
      "alert-#{key}"
    end
  end
end

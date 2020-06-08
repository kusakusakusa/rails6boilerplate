# frozen_string_literal: true

module ApplicationHelper
  def flash_class(key)
    case key
    # from devise
    when 'notice'
      'alert-success'
    when 'alert'
      'alert-danger'
    # custom
    else
      "alert-#{key}"
    end
  end

  def display_date date
    date&.strftime('%b %d, %Y') || '-'
  end
end

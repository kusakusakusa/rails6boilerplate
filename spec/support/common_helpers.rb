# frozen_string_literal: true

module CommonHelpers
  def ajax_click_on text
    click_on text
    sleep 0.1
  end

  def ajax_find_click selector
    find(:css, selector).click
    sleep 0.5
  end

  # wrt https://stackoverflow.com/a/38085926/2667545
  def scroll_to(element)
    script = <<-JS
      arguments[0].scrollIntoView(true);
    JS

    Capybara.current_session.driver.browser.execute_script(script, element.native)
    sleep 0.5
  end

  def set_date selector, date_str
    page.execute_script("document.querySelector('#{selector}').flatpickr().setDate('#{date_str}');")
  end

  def alert_text
    page.driver.browser.switch_to.alert.text
  end

  def validation_text selector, visible: true
    page.find(selector, visible: visible).native.attribute("validationMessage")
  end

  def current_cookies
     page.driver.browser.manage.all_cookies
  end

  def get_cookie key
    current_cookies.find do |cookie|
      cookie[:name] == key
    end
  end
end

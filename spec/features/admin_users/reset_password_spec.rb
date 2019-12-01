# frozen_string_literal: true

require 'rails_helper'

feature 'Forgot password admin user', js: true do
  let!(:admin_user) { create(:admin_user) }

  before :each do
    visit new_admin_user_password_path
    expect(ActionMailer::Base.deliveries.count).to eq 0
    fill_in 'Enter Email Address...', with: admin_user.email
    click_on 'Send me reset password instructions'

    email = ActionMailer::Base.deliveries.last
    expect(ActionMailer::Base.deliveries.count).to eq 1
    doc = Nokogiri::HTML(email.body.to_s)
    @reset_password_url = doc.at_css('[id="reset-password-token"]').attributes['href'].value
  end

  scenario 'should change password successfully' do
    visit URI(@reset_password_url).request_uri # use path as host in test is different
    fill_in 'New password', with: 'newpassword'
    fill_in 'New password confirmation', with: 'newpassword'
    click_on 'Change my password'

    expect(page).to have_content 'Your password has been changed successfully.'

    fill_in 'Email', with: admin_user.email
    fill_in 'Password', with: 'newpassword'
    click_on 'Login'

    expect(page).to have_content 'Signed in successfully.'
    expect(page).to have_current_path(cms_root_path)
  end
end

# frozen_string_literal: true

require 'rails_helper'

feature 'Forgot password admin user', js: true do
  let!(:admin_user) { create(:admin_user) }

  describe 'navigation' do
    scenario 'should navigate to forgot password page upon click from login page' do
      visit new_admin_user_session_path
      click_on 'Forgot your password?'

      expect(page).to have_current_path(new_admin_user_password_path)
    end
  end

  describe 'initiation' do
    before :each do
      visit new_admin_user_password_path
    end

    scenario 'should fail if email is not valid' do
      fill_in 'Enter Email Address...', with: 'wrongadmin@mailinator.com'
      click_on 'Send me reset password instructions'

      expect(page).to have_content('Email not found')
    end

    scenario 'should receive email for password_token' do
      expect(ActionMailer::Base.deliveries.count).to eq 0
      fill_in 'Enter Email Address...', with: admin_user.email
      click_on 'Send me reset password instructions'

      expect(page).to have_content('You will receive an email with instructions on how to reset your password in a few minutes.')
      expect(ActionMailer::Base.deliveries.count).to eq 1
      email = ActionMailer::Base.deliveries.last
      expect(email.to).to include admin_user.email
      expect(email.body).to include 'id="reset-password-token"'
    end

    scenario 'should receive email for password_token' do
      expect(ActionMailer::Base.deliveries.count).to eq 0
      fill_in 'Enter Email Address...', with: admin_user.email
      click_on 'Send me reset password instructions'

      expect(ActionMailer::Base.deliveries.count).to eq 1
      email = ActionMailer::Base.deliveries.last
      expect(email.to).to include admin_user.email
      expect(email.body).to include 'id="reset-password-token"'
    end
  end
end

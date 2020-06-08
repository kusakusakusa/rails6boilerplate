# frozen_string_literal: true

require 'rails_helper'

feature 'Login admin user', js: true do
  let!(:admin_user) { create(:admin_user) }

  before :each do
    visit new_admin_user_session_path
  end

  scenario 'should fail if password is wrong' do
    fill_in 'Email', with: 'cms@mailinator.com'
    fill_in 'Password', with: 'wrongpassword'
    click_on 'Login'

    expect(page).to have_content('Invalid email or password.')
  end

  scenario 'should fail if password is wrong' do
    fill_in 'Email', with: 'wrongcms@mailinator.com'
    fill_in 'Password', with: 'password'
    click_on 'Login'

    expect(page).to have_content('Invalid email or password.')
  end

  scenario 'should pass if credentials are correct' do
    fill_in 'Email', with: 'cms@mailinator.com'
    fill_in 'Password', with: 'password'
    click_on 'Login'

    expect(page).to have_content('Signed in successfully.')
    expect(page).to have_current_path(cms_root_path)
  end

  scenario 'should have validation' do
    click_on 'Login'
    expect(validation_text('#admin_user_email')).to have_content('Please fill in this field.')

    fill_in 'Email', with: 'cms'
    click_on 'Login'
    expect(validation_text('#admin_user_email')).to have_content("Please include an '@' in the email address.")

    fill_in 'Email', with: 'cms@'
    click_on 'Login'
    expect(validation_text('#admin_user_email')).to have_content("Please enter a part following '@'.")

    fill_in 'Email', with: 'cms@mailinator.com'
    click_on 'Login'
    expect(validation_text('#admin_user_password')).to have_content('Please fill in this field.')
  end
end

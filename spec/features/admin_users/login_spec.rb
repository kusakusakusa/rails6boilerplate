# frozen_string_literal: true

require 'rails_helper'

feature 'Login admin user', js: true do
  let!(:admin_user) { create(:admin_user) }

  scenario 'should fail if password is wrong' do
    visit new_admin_user_session_path
    fill_in 'Email', with: 'admin@mailinator.com'
    fill_in 'Password', with: 'wrongpassword'
    click_on 'Login'

    expect(page).to have_content('Invalid email or password.')
  end

  scenario 'should fail if password is wrong' do
    visit new_admin_user_session_path
    fill_in 'Email', with: 'wrongadmin@mailinator.com'
    fill_in 'Password', with: 'password'
    click_on 'Login'

    expect(page).to have_content('Invalid email or password.')
  end

  scenario 'should pass if credentials are correct' do
    visit new_admin_user_session_path
    fill_in 'Email', with: 'admin@mailinator.com'
    fill_in 'Password', with: 'password'
    click_on 'Login'

    expect(page).to have_content('Signed in successfully.')
    expect(page).to have_current_path(cms_root_path)
  end
end

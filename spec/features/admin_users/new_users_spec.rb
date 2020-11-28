# frozen_string_literal: true

require 'rails_helper'

feature 'Create new users from CMS', js: true do
  let!(:admin_user) { create(:admin_user) }

  before :each do
    sign_in admin_user
    visit new_cms_user_path

    fill_in "Email", with: 'test@test.com'
    fill_in "First Name", with: 'firstName'
    fill_in "Last Name", with: 'lastName'
    expect(User.count).to eq 0
    expect(ActionMailer::Base.deliveries.count).to eq 0
  end

  scenario 'should create user with on_temporary_password as true and sent out email' do
    click_on 'Create User'

    expect(page).to have_content 'User successfully created'
    expect(User.count).to eq 1
    expect(page).to have_current_path cms_user_path(User.first)
    expect(User.first.on_temporary_password?).to eq true
    expect(ActionMailer::Base.deliveries.count).to eq 1
    expect(ActionMailer::Base.deliveries.first.subject).to eq "Your account has been created"
  end

  scenario 'should fail if user already present' do
    create(:user, email: 'test@test.com')
    expect(User.count).to eq 1
    click_on 'Create User'

    expect(page).to have_content 'Validation failed: Email has already been taken'
    expect(User.count).to eq 1
  end
end
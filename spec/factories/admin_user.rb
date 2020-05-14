# frozen_string_literal: true

include ActionDispatch::TestProcess

FactoryBot.define do
  factory :admin_user do
    email { 'cms@mailinator.com' }
    password { 'password' }

    avatar { fixture_file_upload(Rails.root.join('app', 'javascript', 'images', 'logo.jpg')) }
  end
end

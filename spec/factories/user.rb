# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.email }
    password { 'password' }

    # default users are confirmed
    before :create do |user|
      user.skip_confirmation!
    end

    trait :unconfirmed do
      before :create do |user|
        user.confirmed_at = nil
      end
    end

    trait :created do
      on_temporary_password { true }
    end
  end
end

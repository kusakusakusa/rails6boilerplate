# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { '12345678' }

    # default users are confirmed
    before :create do |user|
      user.skip_confirmation!
    end

    trait :unconfirmed do
      before :create do |user|
        user.confirmed_at = nil
      end
    end
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory :hygiene_page do
    trait :privacy_policy do
      slug { 'privacy-policy' }
      content { '<h1>Privacy Policy</h1><p>LoremIpsum</p>' }
    end
  end
end

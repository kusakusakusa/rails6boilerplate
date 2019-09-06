# frozen_string_literal: true

FactoryBot.define do
  factory :post do
    title { Faker::Quote.famous_last_words }
    publish_date { Faker::Date.between(from: 2.years.ago, to: Date.yesterday) }
    user
  end
end

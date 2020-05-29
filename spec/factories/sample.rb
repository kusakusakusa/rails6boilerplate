# frozen_string_literal: true

FactoryBot.define do
  factory :sample do
    user

    title { Faker::Lorem.words(number: 4).join(' ') }
    description { Faker::Lorem.paragraph(sentence_count: 6) }
    publish_date { Faker::Date.between(from: 2.years.ago, to: Date.yesterday) }

    featured { false }

    after(:build) do |sample|
      sample.featured_image.attach(io: File.open("#{Rails.root.join('app', 'javascript', 'images')}/default_avatar.jpg"), filename: 'test.jpg')
    end
  end
end

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

      sample.images.attach(io: File.open(Rails.root.join('spec', 'support', 'sample.jpg')), filename: "sample.jpg")
      sample.images.attach(io: File.open(Rails.root.join('spec', 'support', 'another_sample.jpg')), filename: "another_sample.jpg")

      sample.videos.attach(io: File.open(Rails.root.join('spec', 'support', 'sample.mp4')), filename: "sample.mp4")
      sample.videos.attach(io: File.open(Rails.root.join('spec', 'support', 'another_sample.mp4')), filename: "another_sample.mp4")

      sample.audios.attach(io: File.open(Rails.root.join('spec', 'support', 'sample.mp3')), filename: "sample.mp3")
      sample.audios.attach(io: File.open(Rails.root.join('spec', 'support', 'another_sample.mp3')), filename: "another_sample.mp3")
    end
  end
end

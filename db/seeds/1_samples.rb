# frozen_string_literal: true

p 'Creating Samples'

users = User.all

10.times do
  sample = Sample.new(
    title: Faker::Lorem.words(number: 4).join(' '),
    description: Faker::Lorem.paragraph(sentence_count: 6),
    publish_date: Faker::Date.between(from: 1.year.ago, to: Date.today),
    featured: [true, false].sample,
    price: 1000,
    user: users.sample
  )

  sample.featured_image.attach(io: File.open(Rails.root.join('spec', 'support', 'sample.jpg')), filename: "featured_image.jpg")

  sample.images.attach(io: File.open(Rails.root.join('spec', 'support', 'sample.jpg')), filename: "sample.jpg")
  sample.images.attach(io: File.open(Rails.root.join('spec', 'support', 'another_sample.jpg')), filename: "another_sample.jpg")

  sample.videos.attach(io: File.open(Rails.root.join('spec', 'support', 'sample.mp4')), filename: "sample.mp4")
  sample.videos.attach(io: File.open(Rails.root.join('spec', 'support', 'another_sample.mp4')), filename: "another_sample.mp4")

  sample.audios.attach(io: File.open(Rails.root.join('spec', 'support', 'sample.mp3')), filename: "sample.mp3")
  sample.audios.attach(io: File.open(Rails.root.join('spec', 'support', 'another_sample.mp3')), filename: "another_sample.mp3")

  sample.save!
end

p 'Created Samples'
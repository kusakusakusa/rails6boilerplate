# frozen_string_literal: true

p 'Creating Samples'

users = User.all

10.times do
  Sample.create!(
    title: Faker::Lorem.words(number: 4).join(' '),
    description: Faker::Lorem.paragraph(sentence_count: 6),
    publish_date: Faker::Date.between(from: 1.year.ago, to: Date.today),
    featured: [true, false].sample,
    user: users.sample
  )
end

p 'Created Samples'
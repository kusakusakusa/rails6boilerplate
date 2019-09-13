# frozen_string_literal: true

p 'Creating users'
['user1@test.com', 'user2@test.com'].each do |email|
  User.create!(
    first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    email: email,
    password: email,
    confirmed_at: Time.now.utc
  )
end
p 'Users created'

# frozen_string_literal: true

p 'Creating users'
['user1@test.com', 'user2@test.com'].each do |email|
  User.create!(
    email: email,
    password: email,
    confirmed_at: Time.now.utc
  )
end
p 'Users created'

# frozen_string_literal: true

p 'Creating users'
User.create!(
  email: 'user1@test.com',
  password: 'user1@test.com'
)
User.create!(
  email: 'user2@test.com',
  password: 'user2@test.com'
)
p 'Users created'

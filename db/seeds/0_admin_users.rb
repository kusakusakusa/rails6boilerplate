# frozen_string_literal: true

p 'Creating admin user'
AdminUser.create!(
  email: 'admin@test.com',
  password: 'admin@test.com'
)
p 'Admin user created'

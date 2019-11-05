# frozen_string_literal: true

# seeds that also involves production environment
p 'Creating admin user'
AdminUser.create!(
  email: 'admin@test.com',
  password: 'admin@test.com'
)
p 'Admin user created'

# seeds that DO NOT involve production environment
Dir[File.join(Rails.root, 'db', 'seeds', '**/*.rb')].sort.each { |seed| load seed } unless Rails.env.production?

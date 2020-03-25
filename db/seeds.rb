# frozen_string_literal: true

# seeds that also involves production environment
p 'Creating admin user'
admin_user = AdminUser.create!(
  email: 'admin@mailinator.com',
  password: 'admin@mailinator.com'
)
admin_user.avatar.attach(io: File.open("#{Rails.root.join('app', 'javascript', 'images')}/default_avatar.jpg"), filename: 'default_avatar.jpg')
admin_user.save!
p 'Admin user created'

# seeds that DO NOT involve production environment
Dir[File.join(Rails.root, 'db', 'seeds', '**/*.rb')].sort.each { |seed| load seed } unless Rails.env.production?

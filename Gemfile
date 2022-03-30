# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.6.6'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.0.3'
# Use mysql as the database for Active Record
gem 'mysql2', '>= 0.4.4'
# Use Puma as the app server
gem 'puma', '~> 4.3'
# Use SCSS for stylesheets
gem 'sassc', '~>  2.3.0'
gem 'sassc-rails', '~>  2.1.2'
# Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker
gem 'webpacker', '~> 4.0'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.7'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Active Storage variant
# for ckeditor
gem 'image_processing', '~> 1.10.3'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.2', require: false

group :development, :test do
  gem 'letter_opener'
  gem 'pry'
  gem 'rspec-rails', '~> 3.8.0'
end

group :development do
  gem 'annotate', '~> 2.7.5'
  gem 'rename', '~> 1.0.6'
  # Access an interactive console on exception pages or
  # by calling 'console' anywhere in the code.
  gem 'listen', '>= 3.0.5', '< 3.2'
  gem 'rubocop', '~> 0.75.0', require: false
  gem 'slim_lint', '~> 0.17.1'
  gem 'web-console', '>= 3.3.0'

  # for deployment
  gem 'aws-sdk-ec2', '~> 1.112.0'
  gem 'aws-sdk-rds', '~> 1.68.0'
  gem 'bcrypt_pbkdf', '~> 1.0.1' # for OpenSSH to work with Net::SSH tunneling
  gem 'ed25519', '~> 1.2.4' # for OpenSSH to work with Net::SSH tunneling
  gem 'net-ssh-gateway', '~> 2.0.0' # for establishing ssh tunneling from bastion to private instances
end

group :test do
  gem 'capybara', '~> 3.34'
  gem 'factory_bot_rails', '~> 5.0.2'
  gem 'shoulda-matchers', '~> 4.1.2'
  gem 'timecop', '~> 0.9.1'
  # Easy installation and use of web drivers to run system tests with browsers
  gem 'webdrivers', '~> 4.0', require: false
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

gem 'apipie-rails', '~> 0.5.16'
gem 'aws-sdk-s3', '~> 1.64.0'
gem 'ckeditor', '~> 5.1.0'
gem 'cloudwatchlogger', '~> 0.2.1'
gem 'devise', '~> 4.7.1'
gem 'doorkeeper', '~> 5.2.1'
gem 'doorkeeper-jwt', '~> 0.3.0'
gem 'faker', '~> 2.2.1' # for seeding in non development/test env
gem 'jquery-rails', '~> 4.3.5' # required for old gems still relying on assets pipeline
gem 'mini_magick', '~> 4.9.5'
gem 'rack-cors', '~> 1.0.3'
gem 'slim-rails', '~> 3.2.0'
gem 'active_storage_validations', '~> 0.8.9'
gem 'pdfkit', '~> 0.8.4.2'
gem 'natural_sort', '~> 0.3'
gem 'wkhtmltopdf-binary-edge', '~> 0.12.4.0' # dont use 0.12.5.X https://github.com/pallymore/wkhtmltopdf-binary-edge/issues/15
gem 'rpush', '~> 5.0.0'
gem 'enumerize', '~> 2.3.1'
gem 'rest-client', '~> 2.1.0' # for recaptcha

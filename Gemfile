# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.6.5'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.0.0'
# Use mysql as the database for Active Record
gem 'mysql2', '>= 0.4.4'
# Use Puma as the app server
gem 'puma', '~> 3.11'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5'
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
# gem 'image_processing', '~> 1.2'

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
  gem 'mina', '~> 1.2.3'
  gem 'mina-nginx', require: false
  gem 'mina-puma', require: false, github: 'untitledkingdom/mina-puma'
  gem 'rubocop', '~> 0.75.0', require: false
  gem 'slim_lint', '~> 0.17.1'
  gem 'web-console', '>= 3.3.0'
end

group :test do
  gem 'factory_bot_rails', '~> 5.0.2'
  # Adds support for Capybara system testing and selenium driver
  gem 'selenium-webdriver'
  gem 'shoulda-matchers'
  gem 'timecop', '~> 0.9.1'
  # Easy installation and use of web drivers to run system tests with browsers
  gem 'webdrivers'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

gem 'apipie-rails', '~> 0.5.16'
gem 'aws-sdk-s3', require: false
gem 'ckeditor', github: 'galetahub/ckeditor'
gem 'devise', '~> 4.7.1'
gem 'doorkeeper', '~> 5.2.1'
gem 'doorkeeper-jwt', '~> 0.3.0'
gem 'faker', '~> 2.2.1' # for seeding in non development/test env
gem 'jquery-rails', '~> 4.3.5' # required for old gems still relying on assets pipeline
gem 'mini_magick', '~> 4.9.5'
gem 'rack-cors', '~> 1.0.3'
gem 'slim-rails', '~> 3.2.0'

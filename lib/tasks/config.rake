# frozen_string_literal: true

namespace :config do
  desc 'Add to storage.yml file'
  task :add_to_storage_yml, [:env] => :environment do |task, args|
    puts "START - add to config/storage.yml"
    filepath = "#{Rails.root.join('config')}/storage.yml"
    if File.readlines(filepath).grep(/amazon_#{args[:env]}/).size > 0
      puts "config/storage.yml has already been configured for #{args[:env]}!"
      next
    end
    file = File.open(filepath, 'a')
    file.puts <<~MSG
      amazon_#{args[:env]}:
        service: S3
        access_key_id: <%= Rails.application.credentials.dig(:#{args[:env]}, :aws, :access_key_id) %>
        secret_access_key: <%= Rails.application.credentials.dig(:#{args[:env]}, :aws, :secret_access_key) %>
        region: <%= Rails.application.credentials.dig(:#{args[:env]}, :aws, :region) %>
        bucket: <%= Rails.application.credentials.dig(:#{args[:env]}, :aws, :bucket) %>
    MSG
    file.close
    puts "END - add to config/storage.yml"
  end
end

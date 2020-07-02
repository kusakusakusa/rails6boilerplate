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

  desc 'Configure rails environments files'
  task :config_environments_env_rb, [:env] => :environment do |task, args|
    puts "START - create config/environments/#{args[:env]}.yml"
    filepath = "#{Rails.root.join('config', 'environments')}/#{args[:env]}.rb"

    if File.exist?(filepath) && File.readlines(filepath).grep(/amazon_#{args[:env]}/).size > 0
      puts "config/environments/staging.rb has already been created!"
      next
    end

    file = File.open(filepath, 'a')
    file.puts <<~MSG
      # frozen_string_literal: true

      # this env mirrors production except:
      # config.active_storage.service
      # config.action_mailer.delivery_method

      Rails.application.configure do
        config.cache_classes = true
        config.eager_load = true
        config.consider_all_requests_local       = false
        config.action_controller.perform_caching = true
        config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
        config.assets.compile = false
        config.active_storage.service = :amazon_#{args[:env]}
        config.log_level = :debug
        config.log_tags = [ :request_id ]
        config.action_mailer.perform_caching = false
        config.i18n.fallbacks = true
        config.active_support.deprecation = :notify
        config.log_formatter = ::Logger::Formatter.new
        if ENV["RAILS_LOG_TO_STDOUT"].present?
          logger = ActiveSupport::Logger.new(STDOUT)
          logger.formatter = config.log_formatter
          config.logger = ActiveSupport::TaggedLogging.new(logger)
        end
        config.active_record.dump_schema_after_migration = false
      end
    MSG
    file.close
    puts "END - create config/environments/#{args[:env]}.yml"
  end
end

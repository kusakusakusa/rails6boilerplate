# frozen_string_literal: true

desc 'Push all pending notifications'
task rpush_notifications: :environment do
  require Rails.root.join('app', 'concerns', 'loggable.rb')
  include Loggable

  log message: "Rpush.push", log_level: :info, stream: 'test'

  begin
    Rpush.push
  rescue Exception => e
    log message: "Rescued from rpush.rake: #{e.message}\n\n#{e.backtrace}", log_level: :error, stream: 'rpush'
  end
end

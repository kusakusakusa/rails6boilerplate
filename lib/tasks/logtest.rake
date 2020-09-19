# frozen_string_literal: true

desc 'Test rake task and logging'
task logtest: :environment do
  require Rails.root.join('app', 'concerns', 'loggable.rb')
  include Loggable

  log message: "test", log_level: :info, stream: 'test'
end

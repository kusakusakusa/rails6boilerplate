# frozen_string_literal: true

module Loggable
  extend ActiveSupport::Concern

  def log message:, log_level: :info, stream: 'errors'
    return if Rails.env.test?

    logger(stream: stream).send(log_level, message)
  end

  private

  def logger(stream: 'errors')
    return nil if Rails.env.test?

    @logger ||= CloudWatchLogger.new(
      {
        access_key_id: Rails.application.credentials.dig(Rails.env.to_sym, :aws, :cloudwatch, :access_key_id),
        secret_access_key: Rails.application.credentials.dig(Rails.env.to_sym, :aws, :cloudwatch, :secret_access_key)
      },
      "#{Rails.application.class.module_parent_name}-#{Rails.env}",
      stream || 'errors',
      region: Rails.application.credentials.dig(Rails.env.to_sym, :aws, :region)
    )
  end
end

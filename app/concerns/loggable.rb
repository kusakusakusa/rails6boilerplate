# frozen_string_literal: true

module Loggable
  def log message, log_level = :info
    return if Rails.env.test?

    logger.send(log_level, message)
  end

  private

  def logger
    return nil if Rails.env.test?

    @logger ||= CloudWatchLogger.new(
      {
        access_key_id: Rails.application.credentials.dig(Rails.env.to_sym, :aws, :cloudwatch, :access_key_id),
        secret_access_key: Rails.application.credentials.dig(Rails.env.to_sym, :aws, :cloudwatch, :secret_access_key)
      },
      "#{Rails.application.class.module_parent_name}-#{Rails.env}",
      'errors',
      region: Rails.application.credentials.dig(Rails.env.to_sym, :aws, :region)
    )
  end
end

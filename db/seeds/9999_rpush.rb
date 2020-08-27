# frozen_string_literal: true

# Uncomment if doing push notification
# p 'Creating rpush'

# environment = (Rails.env.production? || Rails.env.uat?) ? 'production' : 'development'

# app = Rpush::Apnsp8::App.new
# app.name = Rails.application.config.rpush_app_names[:ios]
# app.apn_key = File.read(Rails.root.join('config', 'apns.p8'))
# app.environment = environment
# app.apn_key_id = Rails.application.credentials.dig(Rails.env.to_sym, :apns, :apn_key_id)
# app.team_id = Rails.application.credentials.dig(Rails.env.to_sym, :apns, :team_id)
# app.bundle_id = Rails.application.credentials.dig(Rails.env.to_sym, :apns, :bundle_id)
# app.connections = 1
# app.save!

# app = Rpush::Gcm::App.new
# app.name = Rails.application.config.rpush_app_names[:android]
# app.auth_key = Rails.application.credentials.dig(Rails.env.to_sym, :fcm, :auth_key)
# app.connections = 1
# app.save!

# p 'Created rpush'

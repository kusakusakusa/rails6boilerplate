# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Rails6boilerplate
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # allow Authorization header to be sent to client
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource(
          '*',
          headers: :any,
          expose: ['Authorization'],
          methods: %i[get patch put delete post options show]
        )
      end
    end

    config.generators do |g|
      g.test_framework :rspec
    end

    # overriding the error message’s format at the model level and at the attribute level
    # wrt https://blog.bigbinary.com/2019/04/22/rails-6-allows-to-override-the-activemodel-errors-full_message-format-at-the-model-level-and-at-the-attribute-level.html
    config.active_model.i18n_customize_full_message

    # constants
    config.confirmation_token_length = 6

    # add concerns
    config.eager_load_paths << Rails.root.join('app', 'concerns')

    config.image_types = %w[
      image/png
      image/jpg
      image/jpeg
    ]

    config.video_types = %w[
      video/x-flv
      video/mp4
      video/x-ms-wmv
    ]

    config.audio_types = %w[
      audio/basic
      audio/mpeg
      audio/vnd.wav
      audio/mp4
    ]

    config.miscellaneous_types = %w[
      text/csv
      application/pdf
    ]
  end
end

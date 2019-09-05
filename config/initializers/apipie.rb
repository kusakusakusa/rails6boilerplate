# frozen_string_literal: true

Apipie.configure do |config|
  config.app_name = Rails.application.class.module_parent_name
  config.api_base_url['v1'] = '/api/v1'
  # config.api_base_url['v2'] = '/api/v2'
  config.doc_base_url = '/apidoc'
  config.default_version = 'v1'
  config.translate = false
  # where is your API defined?
  config.api_controllers_matcher = "#{Rails.root}/app/controllers/**/*.rb"
end

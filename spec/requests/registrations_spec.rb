# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Registrations', type: :request do
  describe 'POST /api/v1/register' do
    scenario 'should fail with too short a password' do
      expect(User.count).to eq 0
      params = {
        email: 'test@test.com',
        password: SecureRandom.alphanumeric(Devise.password_length.to_a.first - 1)
      }

      post user_registration_path, params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 400
      expect(response_body.response_code).to eq 'custom.errors.default'
      expect(response_body.response_message).to eq "Password #{I18n.t('activerecord.errors.models.user.attributes.password.too_short').gsub('%{count}', Devise.password_length.to_a.first.to_s)}"
      expect(User.count).to eq 0
    end

    scenario 'should pass, create user and return user object with proper inputs', :show_in_doc do
      expect(User.count).to eq 0
      params = {
        email: 'test@test.com',
        password: SecureRandom.alphanumeric(Devise.password_length.to_a.first)
      }

      post user_registration_path, params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 200
      expect(response_body.response_code).to eq 'custom.success.default'
      expect(response_body.response_message).to eq I18n.t('custom.success.default')
      expect(User.count).to eq 1
    end
  end
end

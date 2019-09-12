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

      post '/api/v1/register', params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 400
      expect(response_body.response_code).to eq 'custom.errors.devise.registrations'
      expect(response_body.response_message).to eq "#{I18n.t('activerecord.attributes.user.password')} #{I18n.t('activerecord.errors.models.user.attributes.password.too_short').gsub('%{count}', Devise.password_length.to_a.first.to_s)}"
      expect(User.count).to eq 0
    end

    scenario 'should pass, create unconfirmed user and return user object with proper inputs', :show_in_doc do
      expect(User.count).to eq 0
      params = {
        email: 'test@test.com',
        password: SecureRandom.alphanumeric(Devise.password_length.to_a.first)
      }

      post '/api/v1/register', params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 200
      expect(response_body.response_code).to eq 'devise.confirmations.send_instructions'
      expect(response_body.response_message).to eq I18n.t(response_body.response_code)
      expect(User.count).to eq 1
      expect(User.first.confirmed?).to eq false
    end
  end

  describe 'POST /api/v1/user/update-account' do
  end
end

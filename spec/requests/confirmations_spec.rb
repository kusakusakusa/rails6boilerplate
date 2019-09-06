# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Confirmations', type: :request do
  describe 'POST /api/v1/user/confirm' do
    let(:user1) { create(:user, :unconfirmed) }
    let(:user2) { create(:user, :unconfirmed) }

    scenario 'should fail with invalid confirmation_token' do
      expect(user1.confirmed?).to eq false

      params = {
        confirmation_token: 'invalid_code'
      }

      post '/api/v1/user/confirm', params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 400
      expect(response_body.response_code).to eq 'custom.errors.devise.confirmations'

      expect(response_body.response_message).to eq "#{I18n.t('activerecord.attributes.user.confirmation_token')} #{I18n.t('activerecord.errors.models.user.attributes.confirmation_token.invalid')}"
    end

    scenario 'should pass and confirm the correct user with correct confirmation token', :show_in_doc do
      expect(user1.confirmed?).to eq false
      expect(user2.confirmed?).to eq false

      params = {
        confirmation_token: user1.confirmation_token
      }

      post '/api/v1/user/confirm', params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 200
      expect(response_body.response_code).to eq 'custom.success.default'
      expect(response_body.response_message).to eq I18n.t('custom.success.default')

      expect(user1.reload.confirmed?).to eq true
      expect(user2.reload.confirmed?).to eq false
    end
  end

  describe 'GET /api/v1/user/confirm' do
    let(:user) { create(:user, :unconfirmed) }
    let(:confirmed_user) { create(:user) }

    scenario 'should fail if email does not exist' do
      get '/api/v1/user/confirm?email=some@email.com', headers: DEFAULT_HEADERS

      expect(response.status).to eq 400
      expect(response_body.response_code).to eq 'custom.errors.devise.confirmations'
      expect(response_body.response_message).to eq 'Email not found'
    end

    scenario 'should fail if user already confirmed' do
      get "/api/v1/user/confirm?email=#{confirmed_user.email}", headers: DEFAULT_HEADERS

      expect(response.status).to eq 400
      expect(response_body.response_code).to eq 'custom.errors.devise.confirmations'
      expect(response_body.response_message).to include I18n.t('errors.messages.already_confirmed')
    end

    scenario 'should not change confirmation_token' do
      expect(user.confirmed?).to eq false
      initial_confirmation_token = user.confirmation_token

      get "/api/v1/user/confirm?email=#{user.email}", headers: DEFAULT_HEADERS

      expect(response.status).to eq 200
      expect(response_body.response_code).to eq 'custom.success.default'
      expect(response_body.response_message).to eq I18n.t('custom.success.default')
      expect(user.reload.confirmation_token).to eq initial_confirmation_token
    end

    scenario 'should pass when return on unconfirmed user', :show_in_doc do
      get "/api/v1/user/confirm?email=#{user.email}", headers: DEFAULT_HEADERS

      expect(response.status).to eq 200
      expect(response_body.response_code).to eq 'custom.success.default'
      expect(response_body.response_message).to eq I18n.t('custom.success.default')
    end
  end
end

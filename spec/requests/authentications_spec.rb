# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Authentications', type: :request do
  let!(:user) { create(:user) }
  let(:unconfirmed_user) { create(:user, :unconfirmed) }

  describe 'POST /api/v1/user/login' do
    scenario 'should fail with wrong email' do
      params = {
        email: 'wrong@email.com',
        password: '12345678',
        grant_type: 'password'
      }

      post '/api/v1/user/login', params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 400
      expect(response_body.response_code).to eq 'devise.failure.invalid'
      expect(response_body.response_message).to eq I18n.t(response_body.response_code)
    end

    scenario 'should fail with wrong password' do
      params = {
        email: user.email,
        password: 'wrong_password',
        grant_type: 'password'
      }

      post '/api/v1/user/login', params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 400
      expect(response_body.response_code).to eq 'devise.failure.invalid'
      expect(response_body.response_message).to eq I18n.t(response_body.response_code)
    end

    scenario 'should fail with unconfirmed user' do
      params = {
        email: unconfirmed_user.email,
        password: '12345678',
        grant_type: 'password'
      }

      post '/api/v1/user/login', params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 400
      expect(response_body.response_code).to eq 'devise.failure.unconfirmed'
      expect(response_body.response_message).to eq I18n.t(response_body.response_code)
    end

    scenario 'should fail with revoked token after logout'

    scenario 'should get token with correct credentials', :show_in_doc do
      params = {
        email: user.email,
        password: '12345678',
        grant_type: 'password'
      }

      post '/api/v1/user/login', params: params.to_json, headers: DEFAULT_HEADERS

      expect(response_body.access_token).to be_present
      expect(response_body.response_code).to eq 'custom.success.default'
      expect(response_body.response_message).to eq I18n.t('custom.success.default')
    end
  end

  describe 'POST /api/v1/user/refresh' do
    before :each do
      params = {
        email: user.email,
        password: '12345678',
        grant_type: 'password'
      }

      post '/api/v1/user/login', params: params.to_json, headers: DEFAULT_HEADERS

      @access_token = response_body['access_token']
      @refresh_token = response_body['refresh_token']
    end

    scenario 'should fail with invalid refresh_token' do
      params = {
        refresh_token: 'invalid_refresh_token',
        grant_type: 'refresh_token'
      }

      post '/api/v1/user/refresh', params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 400
      expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_grant'
      expect(response_body.response_message).to eq I18n.t('doorkeeper.errors.messages.invalid_grant')
    end

    scenario 'should fail with revoked token after logout'

    scenario 'should return new access_token with valid refresh_token', :show_in_doc do
      params = {
        refresh_token: @refresh_token,
        grant_type: 'refresh_token'
      }

      post '/api/v1/user/refresh', params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 200

      expect(response_body.access_token).to be_present
      expect(response_body.refresh_token).to be_present
      expect(response_body.access_token).not_to eq @access_token
      expect(response_body.refresh_token).not_to eq @refresh_token
      expect(response_body.response_code).to eq 'custom.success.default'
      expect(response_body.response_message).to eq I18n.t('custom.success.default')
    end
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Authentications', type: :request do
  let!(:user) { create(:user) }
  let(:unconfirmed_user) { create(:user, :unconfirmed) }

  describe 'POST /api/v1/login' do
    scenario 'should fail with wrong email' do
      params = {
        email: 'wrong@email.com',
        password: '12345678',
        grant_type: 'password'
      }

      post '/api/v1/login', params: params.to_json, headers: DEFAULT_HEADERS

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

      post '/api/v1/login', params: params.to_json, headers: DEFAULT_HEADERS

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

      post '/api/v1/login', params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 400
      expect(response_body.response_code).to eq 'devise.failure.unconfirmed'
      expect(response_body.response_message).to eq I18n.t(response_body.response_code)
    end

    scenario 'should get token with correct credentials', :show_in_doc do
      params = {
        email: user.email,
        password: '12345678',
        grant_type: 'password'
      }

      post '/api/v1/login', params: params.to_json, headers: DEFAULT_HEADERS

      expect(response_body.access_token).to be_present
      expect(response_body.response_code).to eq 'custom.success.default'
      expect(response_body.response_message).to eq I18n.t('custom.success.default')
    end
  end

  describe 'POST /api/v1/refresh' do
    before :each do
      @access_token, @refresh_token = get_tokens(user)
    end

    scenario 'should fail with invalid refresh_token' do
      params = {
        refresh_token: 'invalid_refresh_token',
        grant_type: 'refresh_token'
      }

      post '/api/v1/refresh', params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 400
      expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_grant'
      expect(response_body.response_message).to eq I18n.t('doorkeeper.errors.messages.invalid_grant')
    end

    scenario 'should fail with revoked refresh_token (after logout)' do
      post '/api/v1/logout', params: {}.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      params = {
        refresh_token: @refresh_token,
        grant_type: 'refresh_token'
      }

      post '/api/v1/refresh', params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 400
      expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_grant'
      expect(response_body.response_message).to eq I18n.t(response_body.response_code)
    end

    scenario 'should fail with revoked access_token (after logout)' do
      post '/api/v1/logout', params: {}.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      params = {
        refresh_token: @refresh_token,
        grant_type: 'refresh_token'
      }

      post '/api/v1/refresh', params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 400
      expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_grant'
      expect(response_body.response_message).to eq I18n.t(response_body.response_code)
    end

    scenario 'should return new access_token with valid refresh_token', :show_in_doc do
      params = {
        refresh_token: @refresh_token,
        grant_type: 'refresh_token'
      }

      post '/api/v1/refresh', params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 200

      expect(response_body.access_token).to be_present
      expect(response_body.refresh_token).to be_present
      expect(response_body.access_token).not_to eq @access_token
      expect(response_body.refresh_token).not_to eq @refresh_token
      expect(response_body.response_code).to eq 'custom.success.default'
      expect(response_body.response_message).to eq I18n.t('custom.success.default')
    end
  end

  describe 'POST /api/v1/logout' do
    before :each do
      @access_token, @refresh_token = get_tokens(user)
    end

    scenario 'should fail with invalid token' do
      post '/api/v1/logout', params: {}.to_json, headers: { 'Authorization': 'Bearer invalid' }.merge!(DEFAULT_HEADERS)

      expect(response.status).to eq 401
      expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_token.unknown'
      expect(response_body.response_message).to eq I18n.t(response_body.response_code)
    end

    scenario 'should pass with valid token' do
      post '/api/v1/logout', params: {}.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      expect(response.status).to eq 200
      expect(response_body.response_code).to eq 'custom.success.default'
      expect(response_body.response_message).to eq I18n.t(response_body.response_code)
    end

    scenario 'should revoke access token', :show_in_doc do
      expect(Doorkeeper::AccessToken.by_token(@access_token).revoked_at).to eq nil
      post '/api/v1/logout', params: {}.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      expect(response_body.response_code).to eq 'custom.success.default'
      expect(Doorkeeper::AccessToken.by_token(@access_token).revoked_at).not_to eq nil
    end

    scenario 'should revoke refresh token too' do
      expect(Doorkeeper::AccessToken.by_refresh_token(@refresh_token).revoked_at).to eq nil
      post '/api/v1/logout', params: {}.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      expect(response_body.response_code).to eq 'custom.success.default'
      expect(Doorkeeper::AccessToken.by_refresh_token(@refresh_token).revoked_at).not_to eq nil
    end

    scenario 'should fail on using expired access token' do
      Timecop.freeze(Time.now + Doorkeeper.configuration.access_token_expires_in.seconds + 1.day) do
        post '/api/v1/logout', params: {}.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

        expect(response.status).to eq 401
        expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_token.expired'
        expect(response_body.response_message).to eq I18n.t response_body.response_code
      end
    end

    scenario 'should fail with revoked access_token (after logout)', :show_in_doc do
      post '/api/v1/logout', params: {}.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      post '/api/v1/logout', params: {}.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      expect(response_body.response_message).to eq I18n.t(response_body.response_code)
      expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_token.revoked'
      expect(response.status).to eq 401
    end

    scenario 'should fail with expired access_token', :show_in_doc do
      Timecop.freeze(Time.now + Doorkeeper.configuration.access_token_expires_in.seconds + 1.day) do
        post '/api/v1/logout', params: {}.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

        expect(response_body.response_message).to eq I18n.t(response_body.response_code)
        expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_token.expired'
        expect(response.status).to eq 401
      end
    end
  end
end

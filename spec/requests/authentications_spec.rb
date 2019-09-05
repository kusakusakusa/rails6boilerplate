# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Authentications', type: :request do
  let!(:user) { create(:user) }

  describe 'POST /api/v1/login' do
    scenario 'should fail with wrong email' do
      params = {
        email: 'wrong@email.com',
        password: '12345678',
        grant_type: 'password'
      }

      post api_v1_login_path, params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 400
    end

    scenario 'should fail with wrong password' do
      params = {
        email: user.email,
        password: 'password',
        grant_type: 'password'
      }

      post api_v1_login_path, params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 400
    end

    scenario 'should get token with correct credentials', :show_in_doc do
      params = {
        email: user.email,
        password: '12345678',
        grant_type: 'password'
      }

      post api_v1_login_path, params: params.to_json, headers: DEFAULT_HEADERS

      expect(response_body['access_token']).to be_present
    end
  end

  describe 'POST /api/v1/refresh' do
    before :each do
      params = {
        email: user.email,
        password: '12345678',
        grant_type: 'password'
      }

      post api_v1_login_path, params: params.to_json, headers: DEFAULT_HEADERS

      @access_token = response_body['access_token']
      @refresh_token = response_body['refresh_token']
    end

    scenario 'should fail with invalid refresh_token' do
      params = {
        refresh_token: 'invalid_refresh_token',
        grant_type: 'refresh_token'
      }

      post api_v1_refresh_path, params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 400
    end

    scenario 'should return new access_token with valid refresh_token', :show_in_doc do
      params = {
        refresh_token: @refresh_token,
        grant_type: 'refresh_token'
      }

      post api_v1_refresh_path, params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.status).to eq 200

      expect(response_body['access_token']).to be_present
    end
  end
end

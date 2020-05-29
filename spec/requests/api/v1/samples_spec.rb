# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Samples', type: :request do
  describe 'GET /api/v1/samples' do
    let!(:user1) { create(:user) }
    let(:user2) { create(:user, email: 'user2@mailinator.com') }
    let(:sample1) { create(:sample, user: user1) }
    let(:sample2) { create(:sample, user: user2) }

    before :each do
      @access_token, @refresh_token = get_tokens(user1)
    end

    scenario 'should fail if there is no access token' do
      get api_v1_samples_path

      expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_token.unknown'
      expect(response_body.response_message).to eq I18n.t response_body.response_code
      expect(response.status).to eq 401
    end

    scenario 'should fail if wrong access token used' do
      get api_v1_samples_path, headers: { 'Authorization': 'Bearer invalid' }.merge!(DEFAULT_HEADERS)
      expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_token.unknown'
      expect(response_body.response_message).to eq I18n.t response_body.response_code
      expect(response.status).to eq 401
    end

    scenario 'should pass with correct access token used' do
      get api_v1_samples_path, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)
      expect(response).to have_http_status(200)
    end

    scenario 'should fail with expired access token used' do
      Timecop.freeze(Time.now + Doorkeeper.configuration.access_token_expires_in.seconds + 1.day) do
        get api_v1_samples_path, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)
        expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_token.expired'
        expect(response_body.response_message).to eq I18n.t response_body.response_code
        expect(response.status).to eq 401
      end
    end

    scenario 'should fail with revoked refresh token used' do
      post '/api/v1/logout', params: {}.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      get api_v1_samples_path, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_token.revoked'
      expect(response_body.response_message).to eq I18n.t response_body.response_code
      expect(response.status).to eq 401
    end

    scenario 'should fail with revoked access token used' do
      post '/api/v1/logout', params: {}.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      get api_v1_samples_path, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_token.revoked'
      expect(response_body.response_message).to eq I18n.t response_body.response_code
      expect(response.status).to eq 401
    end

    scenario "should pass the user's samples", :show_in_doc do
      sample1 # lazyload
      sample2 # lazyload

      get api_v1_samples_path, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      expect(response_body.response_code).to eq 'custom.success.default'
      expect(response_body.response_message).to eq I18n.t response_body.response_code
      samples = response_body.data
      expect(samples.count).to eq 1
      expect(samples.first['id']).to eq sample1.id
    end
  end
end

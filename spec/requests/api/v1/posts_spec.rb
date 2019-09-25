# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Posts', type: :request do
  describe 'GET /api/v1/posts' do
    let!(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:post1) { create(:post, user: user1) }
    let(:post2) { create(:post, user: user2) }

    before :each do
      login_params = {
        email: user1.email,
        password: '12345678',
        grant_type: 'password'
      }

      post '/api/v1/login', params: login_params.to_json, headers: DEFAULT_HEADERS

      @access_token = response_body['access_token']
      @refresh_token = response_body['refresh_token']
    end

    scenario 'should fail if there is no access token' do
      get api_v1_posts_path

      expect(response.status).to eq 401
      expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_token.unknown'
      expect(response_body.response_message).to eq I18n.t response_body.response_code
    end

    scenario 'should fail if wrong access token used' do
      get api_v1_posts_path, headers: DEFAULT_HEADERS.merge!('Authorization': 'Bearer invalid')
      expect(response.status).to eq 401
      expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_token.unknown'
      expect(response_body.response_message).to eq I18n.t response_body.response_code
    end

    scenario 'should pass with correct access token used' do
      get api_v1_posts_path, headers: DEFAULT_HEADERS.merge!('Authorization': "Bearer #{@access_token}")
      expect(response).to have_http_status(200)
    end

    scenario 'should fail with expired access token used' do
      Timecop.freeze(Time.now + Doorkeeper.configuration.access_token_expires_in.seconds + 1.day) do
        get api_v1_posts_path, headers: DEFAULT_HEADERS.merge!('Authorization': "Bearer #{@access_token}")
        expect(response.status).to eq 401
        expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_token.expired'
        expect(response_body.response_message).to eq I18n.t response_body.response_code
      end
    end

    scenario 'should fail with revoked refresh token used' do
      post '/api/v1/logout', params: {}.to_json, headers:DEFAULT_HEADERS.merge!('Authorization': "Bearer #{@access_token}")

      get api_v1_posts_path, headers: DEFAULT_HEADERS.merge!('Authorization': "Bearer #{@access_token}")

      expect(response.status).to eq 401
      expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_token.revoked'
      expect(response_body.response_message).to eq I18n.t response_body.response_code
    end

    scenario 'should fail with revoked access token used' do
      post '/api/v1/logout', params: {}.to_json, headers:DEFAULT_HEADERS.merge!('Authorization': "Bearer #{@access_token}")

      get api_v1_posts_path, headers: DEFAULT_HEADERS.merge!('Authorization': "Bearer #{@access_token}")

      expect(response.status).to eq 401
      expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_token.revoked'
      expect(response_body.response_message).to eq I18n.t response_body.response_code
    end

    scenario "should pass the user's posts", :show_in_doc do
      post1 # lazyload
      post2 # lazyload

      get api_v1_posts_path, headers: DEFAULT_HEADERS.merge!('Authorization': "Bearer #{@access_token}")

      expect(response_body.response_code).to eq 'custom.success.default'
      expect(response_body.response_message).to eq I18n.t response_body.response_code
      posts = response_body.data
      expect(posts.count).to eq 1
      expect(posts.first['id']).to eq post1.id
    end
  end
end

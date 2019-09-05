# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Posts', type: :request do
  describe 'GET /api/v1/posts' do
    let!(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:post1) { create(:post, user: user1) }
    let(:post2) { create(:post, user: user2) }

    before :each do
      reg_params = {
        user: {
          email: 'test@test.com',
          password: 'password'
        }
      }

      post user_registration_path, params: reg_params.to_json, headers: DEFAULT_HEADERS

      cookies.delete "_#{Rails.application.class.module_parent_name.downcase}_session"

      login_params = {
        email: user1.email,
        password: '12345678',
        grant_type: 'password'
      }

      post api_v1_login_path, params: login_params.to_json, headers: DEFAULT_HEADERS

      @access_token = JSON.parse(response.body)['access_token']
      @refresh_token = JSON.parse(response.body)['refresh_token']
    end

    scenario 'should fail if there is not access token' do
      get api_v1_posts_path
      expect(response).to have_http_status(401)
    end

    scenario 'should fail if wrong access token used' do
      get api_v1_posts_path, headers: { 'Authorization': 'Bearer invalid' }
      expect(response).to have_http_status(401)
    end

    scenario 'should pass with correct access token used' do
      get api_v1_posts_path, headers: { 'Authorization': "Bearer #{@access_token}" }
      expect(response).to have_http_status(200)
    end

    scenario "should pass the user's posts" do
      post1 # lazyload
      post2 # lazyload

      get api_v1_posts_path, headers: { 'Authorization': "Bearer #{@access_token}" }

      posts = JSON.parse(response.body)
      expect(posts.count).to eq 1
      expect(posts.first['id']).to eq post1.id
    end
  end
end

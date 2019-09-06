# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Passwords', type: :request do
  describe 'GET /api/v1/user/forgot-password' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:unconfirmed_user) { create(:user, :unconfirmed) }

    scenario 'should fail on invalid email' do
      get '/api/v1/user/forgot-password?email=some@email.com', headers: DEFAULT_HEADERS

      expect(response_body.response_code).to eq 'custom.errors.devise.passwords'
      expect(response_body.response_message).to eq 'Email not found'
    end

    scenario 'should pass on unconfirmed user' do
      get "/api/v1/user/forgot-password?email=#{unconfirmed_user.email}", headers: DEFAULT_HEADERS

      expect(response_body.response_code).to eq 'custom.success.default'
      expect(response_body.response_message).to eq I18n.t(response_body.response_code)
    end

    scenario 'should have different reset_password_token changed on subsequent calls' do
      expect(user1.reset_password_token).to eq nil

      get "/api/v1/user/forgot-password?email=#{user1.email}", headers: DEFAULT_HEADERS

      reset_password_token = user1.reload.reset_password_token
      expect(reset_password_token).not_to eq nil

      get "/api/v1/user/forgot-password?email=#{user1.email}", headers: DEFAULT_HEADERS

      new_reset_password_token = user1.reload.reset_password_token
      expect(reset_password_token).not_to eq new_reset_password_token
    end

    scenario 'should reset the correct user reset_password_token', :show_in_doc do
      expect(user1.reset_password_token).to eq nil
      expect(user2.reset_password_token).to eq nil
      get "/api/v1/user/forgot-password?email=#{user1.email}", headers: DEFAULT_HEADERS

      expect(user1.reload.reset_password_token).not_to eq nil
      expect(user2.reload.reset_password_token).to eq nil
    end
  end
end

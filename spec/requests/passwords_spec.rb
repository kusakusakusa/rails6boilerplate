# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Passwords', type: :request do
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:unconfirmed_user) { create(:user, :unconfirmed) }

  describe 'GET /api/v1/user/forgot-password' do
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

  describe 'POST /api/v1/user/reset-password' do
    scenario 'should send email' do
      expect(ActionMailer::Base.deliveries.count).to eq 0
      get "/api/v1/user/forgot-password?email=#{user1.email}", headers: DEFAULT_HEADERS
      expect(ActionMailer::Base.deliveries.count).to eq 1
      email = ActionMailer::Base.deliveries.last
      expect(email.to).to include user1.email
      expect(email.body).to include "id='reset-password-token'"
    end

    scenario 'should implicitly confirm unconfirmed users' do
      unconfirmed_user # lazyload
      ActionMailer::Base.deliveries.clear # clean emails
      expect(ActionMailer::Base.deliveries.count).to eq 0
      get "/api/v1/user/forgot-password?email=#{unconfirmed_user.email}", headers: DEFAULT_HEADERS

      # get reset_password_token
      expect(ActionMailer::Base.deliveries.count).to eq 1
      doc = Nokogiri::HTML(ActionMailer::Base.deliveries.first.body.to_s)
      reset_password_token = doc.at_css('[id="reset-password-token"]').text

      params = {
        reset_password_token: reset_password_token,
        password: 'new_password'
      }

      post '/api/v1/user/reset-password', params: params.to_json, headers: DEFAULT_HEADERS

      expect(unconfirmed_user.reload.confirmed?).to eq true
    end

    scenario 'should change user password successfully', :show_in_doc do
      expect(ActionMailer::Base.deliveries.count).to eq 0
      get "/api/v1/user/forgot-password?email=#{user1.email}", headers: DEFAULT_HEADERS

      # get reset_password_token
      expect(ActionMailer::Base.deliveries.count).to eq 1
      doc = Nokogiri::HTML(ActionMailer::Base.deliveries.first.body.to_s)
      reset_password_token = doc.at_css('[id="reset-password-token"]').text

      params = {
        reset_password_token: reset_password_token,
        password: 'new_password'
      }

      post '/api/v1/user/reset-password', params: params.to_json, headers: DEFAULT_HEADERS

      expect(user1.reload.reset_password_token).to eq nil

      params = {
        email: user1.email,
        password: 'new_password',
        grant_type: 'password'
      }

      post '/api/v1/user/login', params: params.to_json, headers: DEFAULT_HEADERS

      expect(response_body.access_token).to be_present
      expect(response_body.response_code).to eq 'custom.success.default'
      expect(response_body.response_message).to eq I18n.t('custom.success.default')
    end
  end
end

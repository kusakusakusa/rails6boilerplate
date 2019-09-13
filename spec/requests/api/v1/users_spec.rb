# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users', type: :request do
  describe 'POST /api/v1/update-profile' do
    let(:user) { create(:user) }

    before :each do
      login_params = {
        email: user.email,
        password: '12345678',
        grant_type: 'password'
      }

      post '/api/v1/login', params: login_params.to_json, headers: DEFAULT_HEADERS

      @access_token = response_body['access_token']
      @refresh_token = response_body['refresh_token']
    end

    scenario 'should pass with missing params and not change those attributes' do
      old_last_name = user.last_name
      params = {
        first_name: 'newFirstName'
      }

      post '/api/v1/update-profile', params: params.to_json, headers: DEFAULT_HEADERS.merge!('Authorization': "Bearer #{@access_token}")

      expect(response.status).to eq 200
      expect(user.reload.first_name).to eq 'newFirstName'
      expect(user.reload.last_name).to eq old_last_name
    end

    scenario 'should pass with correct credentials', :show_in_doc do
      params = {
        first_name: 'newFirstName',
        last_name: 'newLastName'
      }
      post '/api/v1/update-profile', params: params.to_json, headers: DEFAULT_HEADERS.merge!('Authorization': "Bearer #{@access_token}")

      expect(response.status).to eq 200
      expect(user.reload.first_name).to eq 'newFirstName'
      expect(user.reload.last_name).to eq 'newLastName'
    end
  end
end

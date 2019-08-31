require 'rails_helper'

RSpec.describe "Authentications", type: :request do
  describe "POST /api/v1/users/login" do
    before :each do
      params = {
        user: {
          email: "test@test.com",
          password: "password"
        }
      }

      post user_registration_path, params: params.to_json, headers: DEFAULT_HEADERS

      cookies.delete "_#{Rails.application.class.module_parent_name.downcase}_session"
    end

    scenario 'should fail with wrong email' do
      params = {
        user: {
          email: "wrong@email.com",
          password: "password"
        }
      }

      post user_session_path, params: params.to_json, headers: DEFAULT_HEADERS
      expect(response.headers['Authorization']).not_to be_present
      expect(response.status).to eq 401
    end

    scenario 'should fail with wrong email' do
      params = {
        user: {
          email: "wrong@email.com",
          password: "password"
        }
      }

      post user_session_path, params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.headers['Authorization']).not_to be_present
      expect(response.status).to eq 401
    end

    scenario 'should get token with correct credentials' do
      params = {
        user: {
          email: "test@test.com",
          password: "password"
        }
      }

      post user_session_path, params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.headers['Authorization']).to be_present
    end
  end
end

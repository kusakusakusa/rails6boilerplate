require 'rails_helper'

RSpec.describe 'Registrations', type: :request do
  describe 'POST /api/v1/users/signup' do
    scenario 'should fail with too short a password' do
      expect(User.count).to eq 0
      params = {
        user: {
          email: 'test@test.com',
          password: SecureRandom.alphanumeric(Devise.password_length.to_a.first - 1)
        }
      }

      post user_registration_path, params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.headers['Authorization']).not_to be_present
      expect(response.status).to eq 422

      expect(User.count).to eq 0
    end

    scenario 'should fail with invalid a password' do
      expect(User.count).to eq 0
      params = {
        user: {
          email: 'testtest',
          password: SecureRandom.alphanumeric(Devise.password_length.to_a.first - 1)
        }
      }

      post user_registration_path, params: params.to_json, headers: DEFAULT_HEADERS

      expect(response.headers['Authorization']).not_to be_present
      expect(response.status).to eq 422

      expect(User.count).to eq 0
    end
  end
end

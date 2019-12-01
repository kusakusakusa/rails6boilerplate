# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users', type: :request do
  let(:user) { create(:user) }
  describe 'POST /api/v1/update-profile' do
    before :each do
      @access_token, @refresh_token = get_tokens(user)
    end

    scenario 'should pass with missing params and not change those attributes' do
      old_last_name = user.last_name
      params = {
        first_name: 'newFirstName'
      }

      post '/api/v1/update-profile', params: params.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      expect(response.status).to eq 200
      expect(user.reload.first_name).to eq 'newFirstName'
      expect(user.reload.last_name).to eq old_last_name
    end

    scenario 'should pass with correct credentials', :show_in_doc do
      params = {
        first_name: 'newFirstName',
        last_name: 'newLastName'
      }
      post '/api/v1/update-profile', params: params.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      expect(response.status).to eq 200
      expect(user.reload.first_name).to eq 'newFirstName'
      expect(user.reload.last_name).to eq 'newLastName'
    end

    describe '.json_attributes' do
      scenario 'should not contain encrypted_password' do
        expect(user.json_attributes.key?('encrypted_password')).to eq false
      end

      scenario 'should not contain reset_password_token' do
        expect(user.json_attributes.key?('reset_password_token')).to eq false
      end

      scenario 'should not contain reset_password_sent_at' do
        expect(user.json_attributes.key?('reset_password_sent_at')).to eq false
      end

      scenario 'should not contain remember_created_at' do
        expect(user.json_attributes.key?('remember_created_at')).to eq false
      end

      scenario 'should not contain confirmation_token' do
        expect(user.json_attributes.key?('confirmation_token')).to eq false
      end

      scenario 'should not contain confirmed_at' do
        expect(user.json_attributes.key?('confirmed_at')).to eq false
      end

      scenario 'should not contain confirmation_sent_at' do
        expect(user.json_attributes.key?('confirmation_sent_at')).to eq false
      end
    end
  end
end

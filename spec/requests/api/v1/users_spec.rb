# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users', type: :request do
  let!(:user) { create(:user) }
  let!(:created_user) { create(:user, :created) }

  before :each do
    @access_token, @refresh_token = get_tokens(user)
  end

  feature 'authentication' do
    [
      {
        http_action: 'get',
        url: '/api/v1/get-profile',
        params: {},
      },
      {
        http_action: 'post',
        url: '/api/v1/update-profile',
        params: {
          first_name: 'First Name'
        },
      },
      {
        http_action: 'post',
        url: '/api/v1/update-password',
        params: {
          current_password: 'password',
          password: 'newpassword',
        },
      }
    ].each do |setting|
      feature "#{setting[:http_action].upcase} #{setting[:url]}" do
        scenario 'should fail without token', :show_in_doc do
          send(setting[:http_action], setting[:url], headers: DEFAULT_HEADERS, params: setting[:params].to_json)

          expect(response_body.response_message).to eq 'The access token is invalid'
          expect(response_body.response_code).to eq 'doorkeeper.errors.messages.invalid_token.unknown'
          expect(response.status).to eq 401
        end
      end
    end
  end

  describe 'GET /api/v1/get-profile' do
    scenario 'should get correct user profile', :show_in_doc do
      another_user = create(:user)
      access_token, refresh_token = get_tokens(user)
      get '/api/v1/get-profile', headers: { 'Authorization': "Bearer #{access_token}" }.merge!(DEFAULT_HEADERS)
      expect(response.status).to eq 200
      expect(response_body.user.id).to eq user.id

      access_token, refresh_token = get_tokens(another_user)

      get '/api/v1/get-profile', headers: { 'Authorization': "Bearer #{access_token}" }.merge!(DEFAULT_HEADERS)
      expect(response.status).to eq 200
      expect(response_body.user.id).to eq another_user.id
    end
  end

  describe 'POST /api/v1/update-profile' do
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

  describe 'POST /api/v1/update-avatar' do
    before :each do
      expect(user.avatar.attached?).to eq false
    end

    scenario 'should pass with correct credentials', :show_in_doc do
      params = { avatar: image_base64 }

      post '/api/v1/update-avatar', params: params.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      expect(response_body.response_message).to eq 'Success!'
      expect(response_body.response_code).to eq 'custom.success.default'
      expect(response.status).to eq 200
      expect(user.reload.avatar.attached?).to eq true
    end

    scenario 'should fail if there is no extension', :show_in_doc do
      params = { avatar: image_no_extension_base64 }

      post '/api/v1/update-avatar', params: params.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      expect(response_body.response_message).to eq 'no extension'
      expect(response_body.response_code).to eq 'custom.errors.users.update_avatar'
      expect(response.status).to eq 400
      expect(user.reload.avatar.attached?).to eq false
    end

    scenario 'should fail to upload image if params is unsafeurl base64', :show_in_doc do
      params = { avatar: image_unsafe_base64 }

      post '/api/v1/update-avatar', params: params.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      expect(response_body.response_message).to eq 'invalid base64'
      expect(response_body.response_code).to eq "custom.errors.users.update_avatar"
      expect(response.status).to eq 400
      expect(user.reload.avatar.attached?).to eq false
    end

    scenario 'should fail if non image is uploaded' do
      params = { avatar: video_base64 }

      post '/api/v1/update-avatar', params: params.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      expect(response_body.response_message).to eq 'Avatar has an invalid content type'
      expect(response_body.response_code).to eq "custom.errors.users.update_avatar"
      expect(response.status).to eq 400
      expect(user.reload.avatar.attached?).to eq false
    end
  end

  describe 'POST /api/v1/update-password' do
    before :each do
      @params = {
        current_password: 'password',
        password: 'newpassword'
      }
    end

    scenario 'should fail if wrong current password is given', :show_in_doc do
      @params[:current_password] = 'wrongpassword'
      post '/api/v1/update-password', params: @params.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      expect(response_body.response_message).to eq 'Your current password is wrong'
      expect(response_body.response_code).to eq 'custom.errors.users.wrong_current_password'
      expect(response.status).to eq 403
    end

    scenario 'should fail if password is too short', :show_in_doc do
      @params[:password] = Faker::Lorem.characters(number: Devise.password_length.first - 1)
      post '/api/v1/update-password', params: @params.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      expect(response_body.response_message).to eq 'Your password is too short (minimum is 6 characters)'
      expect(response_body.response_code).to eq 'custom.errors.users.update_password'
      expect(response.status).to eq 400
    end

    scenario 'should successfully change user password', :show_in_doc do
      initial_encrypted_password = user.encrypted_password
      post '/api/v1/update-password', params: @params.to_json, headers: { 'Authorization': "Bearer #{@access_token}" }.merge!(DEFAULT_HEADERS)

      expect(response_body.response_code).to eq 'custom.success.default'
      expect(response_body.response_message).to eq I18n.t('custom.success.default')
      expect(response.status).to eq 200
      expect(user.reload.encrypted_password).not_to eq initial_encrypted_password
    end

    scenario 'should update user on_temporary_password to false' do
      access_token, refresh_token = get_tokens(created_user)
      expect(created_user.on_temporary_password?).to eq true

      post '/api/v1/update-password', params: @params.to_json, headers: { 'Authorization': "Bearer #{access_token}" }.merge!(DEFAULT_HEADERS)

      expect(response_body.response_code).to eq 'custom.success.default'
      expect(response_body.response_message).to eq I18n.t('custom.success.default')
      expect(response.status).to eq 200

      expect(created_user.reload.on_temporary_password?).to eq false
    end
  end
end

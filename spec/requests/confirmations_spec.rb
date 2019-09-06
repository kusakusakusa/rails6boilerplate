# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Confirmations', type: :request do
  describe 'GET /api/v1/confirm' do
    let(:user1) { create(:user, :unconfirmed) }
    let(:user2) { create(:user, :unconfirmed) }

    scenario 'should fail with invalid confirmation_token' do
      expect(user1.confirmed?).to eq false

      get '/api/v1/confirm?confirmation_token=invalid_code', headers: DEFAULT_HEADERS

      expect(response.status).to eq 400
      expect(response_body.response_code).to eq 'custom.errors.devise.confirmations'

      expect(response_body.response_message).to eq "#{I18n.t('activerecord.attributes.user.confirmation_token')} #{I18n.t('activerecord.errors.models.user.attributes.confirmation_token.invalid')}"
    end

    scenario 'should pass and confirm the correct user with correct confirmation token', :show_in_doc do
      expect(user1.confirmed?).to eq false
      expect(user2.confirmed?).to eq false

      get "/api/v1/confirm?confirmation_token=#{user1.confirmation_token}", headers: DEFAULT_HEADERS

      expect(response.status).to eq 200
      expect(response_body.response_code).to eq 'custom.success.default'
      expect(response_body.response_message).to eq I18n.t('custom.success.default')

      expect(user1.reload.confirmed?).to eq true
      expect(user2.reload.confirmed?).to eq false
    end
  end
end

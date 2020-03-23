# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Healthcheck', type: :request do
  describe 'GET /healthcheck' do
    scenario 'should return 200 for application/json format' do
      get '/healthcheck', headers: DEFAULT_HEADERS
      expect(response.body).to eq ''
      expect(response.status).to eq 200
    end

    scenario 'should return 200 for text/html format' do
      get '/healthcheck', headers: {
        'CONTENT_TYPE' => 'text/html',
        'ACCEPT' => 'text/html'
      }
      expect(response.body).to eq ''
      expect(response.status).to eq 200
    end
  end
end

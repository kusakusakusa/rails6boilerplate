# frozen_string_literal: true

class UserSessionsController < Devise::SessionsController
  respond_to :json
  skip_before_action :verify_authenticity_token

  resource_description do
    resource_id 'sessions'
    api_versions 'v1' # , 'v2'
  end

  api :POST, '/user/login', 'Login user. Returns JWT token in Authorization header.'
  description 'Returns JWT token in Authorization header.'
  param :user, Hash, desc: 'User resource' do
    param :email, URI::MailTo::EMAIL_REGEXP, required: true
    param :password, String, required: true, desc: "Length #{Devise.password_length.to_a.first} to #{Devise.password_length.to_a.last}"
  end
  def create
    super
  end

  private

  def respond_with(resource, _opts = {})
    render json: resource
  end

  def respond_to_on_destroy
    head :ok
  end
end

# frozen_string_literal: true

module TokenHelpers
  def get_tokens user
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, scopes: "public manage")
    token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, use_refresh_token: true, expires_in: Doorkeeper.configuration.access_token_expires_in)

    [token.token, token.refresh_token]
  end
end

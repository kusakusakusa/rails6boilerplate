# frozen_string_literal: true

module Api
  module V1
    class PostsController < ApplicationController
      before_action :doorkeeper_authorize!

      def current_user
        @current_user ||= if doorkeeper_token
                            User.find(doorkeeper_token.resource_owner_id)
                          else
                            warden.authenticate(scope: :user)
                          end
      end

      def index
        @posts = current_user.posts
      end
    end
  end
end

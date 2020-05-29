# frozen_string_literal: true

module Api
  module V1
    class SamplesController < Api::BaseController
      resource_description do
        name 'Samples'
        resource_id 'Samples'
        api_versions 'v1' # , 'v2'
      end

      api :GET, '/samples', "Returns all of user's samples"
      description "Returns all of user's samples"
      header 'Authorization', 'Bearer [your_access_token]', required: true
      def index
        @samples = current_user.samples
      end
    end
  end
end

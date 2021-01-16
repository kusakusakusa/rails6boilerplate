# frozen_string_literal: true

module Api
  module Experiment
    class BaseController < ActionController::API
      # order or macros matter
      before_action :add_default_response_keys

      include ApiRescues

      def send_emails
        5.times.each do
          ApplicationMailer.send_emails(Sample.first).deliver
        end

        render template: 'api/base/default', status: 200
      end
    end
  end
end

# frozen_string_literal: true

module Purgeable
  extend ActiveSupport::Concern

  def purge_attachment attachment
    begin
      attachment.purge
    rescue Aws::S3::Errors::AccessDenied => e
      # triggered when attachment does not have variants
      # and ActiveStorage callsDeleted files by key prefix: variants/xxxxxx/
    end
  end
end

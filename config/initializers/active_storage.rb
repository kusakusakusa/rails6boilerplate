# frozen_string_literal: true

module ActiveStorageAttachmentExtension
  extend ActiveSupport::Concern

  def video?
    Rails.application.config.video_types.include? blob.content_type
  end

  def image?
    Rails.application.config.image_types.include? blob.content_type
  end

  def audio?
    Rails.application.config.audio_types.include? blob.content_type
  end
end

Rails.configuration.to_prepare do
  ActiveStorage::Attachment.send :include, ::ActiveStorageAttachmentExtension
end

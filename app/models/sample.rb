# frozen_string_literal: true

# == Schema Information
#
# Table name: samples
#
#  id           :bigint           not null, primary key
#  user_id      :bigint
#  title        :string(255)
#  description  :text(65535)
#  publish_date :date
#  price        :integer
#  featured     :boolean          default(FALSE), not null
#  status       :string(255)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

class Sample < ApplicationRecord
  include NaturalSortable, Featurable

  belongs_to :user, optional: true #, inverse_of: :samples

  
  has_many_attached :images
  has_many_attached :videos
  has_many_attached :audios

  validates :images,
            content_type: Rails.application.config.image_types
  validates :videos,
            content_type: Rails.application.config.video_types
  validates :audios,
            content_type: Rails.application.config.audio_types
end

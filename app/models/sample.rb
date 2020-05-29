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
#  featured     :boolean          default(FALSE), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

class Sample < ApplicationRecord
  belongs_to :user, optional: true #, inverse_of: :samples

  has_one_attached :featured_image
  has_many_attached :images

  validates :featured_image,
            attached: true,
            content_type: ['image/png', 'image/jpg', 'image/jpeg']
  validates :images,
            content_type: ['image/png', 'image/jpg', 'image/jpeg']
end

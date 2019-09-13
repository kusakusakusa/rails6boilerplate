# == Schema Information
#
# Table name: posts
#
#  id           :bigint           not null, primary key
#  user_id      :bigint
#  title        :string(255)
#  publish_date :date
#  content      :text(65535)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

class Post < ApplicationRecord
  belongs_to :user

  has_one_attached :cover_image
end

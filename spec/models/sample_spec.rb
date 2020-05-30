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
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

require 'rails_helper'

RSpec.describe Sample, type: :model do
  it { should validate_attached_of(:featured_image) }
  it { should validate_content_type_of(:featured_image).allowing('image/png', 'image/jpg', 'image/jpeg') }
  it { should validate_content_type_of(:images).allowing('image/png', 'image/jpg', 'image/jpeg') }
  it { should validate_content_type_of(:videos).allowing('video/x-flv', 'video/mp4', 'video/x-ms-wmv') }
  it { should validate_content_type_of(:audios).allowing('audio/basic', 'audio/mpeg', 'audio/vnd.wav', 'audio/mp4') }
end


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

require 'rails_helper'

RSpec.describe Sample, type: :model do
  it { should validate_attached_of(:featured_image) }
  it { should validate_content_type_of(:featured_image).allowing(Rails.application.config.image_types) }
  it { should validate_content_type_of(:images).allowing(Rails.application.config.image_types) }
  it { should validate_content_type_of(:videos).allowing(Rails.application.config.video_types) }
  it { should validate_content_type_of(:audios).allowing(Rails.application.config.audio_types) }

  feature 'scopes' do
    feature '.naturally_sorted' do
      scenario 'should sort alpha numerically' do
        sample1 = create(:sample, title: '10')
        sample2 = create(:sample, title: '1')
        expect(Sample.all.first.id).to eq sample1.id 
        expect(Sample.unscoped.naturally_sorted(:title).first.id).to eq sample2.id 
      end
    end
  end
end


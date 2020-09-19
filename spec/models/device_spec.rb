# frozen_string_literal: true

# == Schema Information
#
# Table name: devices
#
#  id          :bigint           not null, primary key
#  user_id     :bigint
#  token       :string(191)
#  device_type :string(7)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#


require 'rails_helper'

RSpec.describe Device, type: :model do
  it { should belong_to(:user) }
  it { should validate_presence_of(:token) }
  it { should validate_presence_of(:device_type) }
end

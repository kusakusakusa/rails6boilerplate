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


class Device < ApplicationRecord
  belongs_to :user, inverse_of: :devices

  extend Enumerize

  enumerize :device_type, in: %i[ios android], predicates: true

  validates :token,
            :device_type,
            presence: true
end

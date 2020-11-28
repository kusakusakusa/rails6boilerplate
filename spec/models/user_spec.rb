# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  email                  :string(255)      default(""), not null
#  encrypted_password     :string(255)      default(""), not null
#  reset_password_token   :string(255)
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  confirmation_token     :string(255)
#  confirmed_at           :datetime
#  confirmation_sent_at   :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  first_name             :string(255)
#  last_name              :string(255)
#  on_temporary_password  :boolean
#


require 'rails_helper'

RSpec.describe User, type: :model do
  it { should validate_content_type_of(:avatar).allowing(Rails.application.config.image_types) }
  it { should validate_presence_of(:first_name) }
  it { should validate_presence_of(:last_name) }
  it { should validate_presence_of(:email) }

  it { should have_many(:devices) }

  feature 'instance_methods' do
    feature '#full_name' do
      let!(:user) { create(:user) }

      scenario 'should return full name' do
        expect(user.full_name).to eq "#{user.first_name} #{user.last_name}"
      end
    end

    feature '#full_title' do
      let!(:user) { create(:user) }

      scenario 'should return full title' do
        expect(user.full_title).to eq "#{user.first_name} #{user.last_name} (#{user.email})"
      end
    end
  end
end

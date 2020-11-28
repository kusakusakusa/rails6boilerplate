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

class User < ApplicationRecord
  include Userable, Avatarable, Devicable, Createable

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :confirmable,
         :validatable

  has_many :samples

  def json_attributes
    custom_attributes = super
    custom_attributes.delete 'encrypted_password'
    custom_attributes.delete 'reset_password_token'
    custom_attributes.delete 'reset_password_sent_at'
    custom_attributes.delete 'remember_created_at'
    custom_attributes.delete 'confirmation_token'
    custom_attributes.delete 'confirmed_at'
    custom_attributes.delete 'confirmation_sent_at'
    custom_attributes
  end
end

class User::ParameterSanitizer < Devise::ParameterSanitizer
  def initialize(*)
    super
    permit(:account_update, keys: [:first_name, :last_name, :password, :current_password])
  end
end

# frozen_string_literal: true

# this module is for requirement where the user need to be able to be added in cms
module Createable
  extend ActiveSupport::Concern

  included do
    before_update :update_temporary_password, if: :will_save_change_to_encrypted_password?
  end

  def on_temporary_password?
    on_temporary_password
  end

  def update_temporary_password
    if on_temporary_password?
      self.on_temporary_password = false
    end
  end
end

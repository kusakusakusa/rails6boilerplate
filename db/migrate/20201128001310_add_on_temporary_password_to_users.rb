class AddOnTemporaryPasswordToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :on_temporary_password, :boolean
  end
end

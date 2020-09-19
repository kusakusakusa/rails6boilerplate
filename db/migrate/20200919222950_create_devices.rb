class CreateDevices < ActiveRecord::Migration[6.0]
  def change
    create_table :devices do |t|
      t.references :user, index: true
      t.string :token, limit: 191
      t.string :device_type, limit: 7

      t.timestamps
    end
  end
end

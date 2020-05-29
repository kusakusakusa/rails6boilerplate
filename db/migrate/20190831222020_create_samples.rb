class CreateSamples < ActiveRecord::Migration[6.0]
  def change
    create_table :samples do |t|
      t.references :user
      t.string :title
      t.text :description
      t.date :publish_date
      t.integer :price, limit: 3
      t.boolean :featured, default: false, null: false

      t.timestamps
    end
  end
end

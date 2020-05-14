class CreateHygienePages < ActiveRecord::Migration[6.0]
  def change
    create_table :hygiene_pages do |t|
      t.string :slug, limit: 191, index: true
      t.text :content

      t.timestamps
    end
  end
end

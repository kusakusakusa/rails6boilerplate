# frozen_string_literal: true

class CreateDoorkeeperTables < ActiveRecord::Migration[6.0]
  def change
    create_table :oauth_access_tokens do |t|
      t.references :resource_owner, index: true
      t.integer :application_id
      t.text :token, null: false
      t.string :refresh_token
      t.integer :expires_in
      t.datetime :revoked_at
      t.datetime :created_at, null: false
      t.string :scopes
    end

    # required to allow model.destroy to work
    create_table :oauth_access_grants do |t|
      t.references :resource_owner, null: false
      t.integer :application_id
      t.string   :token, null: false
      t.integer  :expires_in, null: false
      t.text     :redirect_uri, null: false
      t.datetime :created_at, null: false
      t.datetime :revoked_at
      t.string   :scopes, null: false, default: ''
    end

    # Uncomment below to ensure a valid reference to the resource owner's table
    add_foreign_key :oauth_access_tokens, :users, column: :resource_owner_id
  end
end

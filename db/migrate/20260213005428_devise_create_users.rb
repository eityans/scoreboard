# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.datetime :remember_created_at

      t.string :provider, null: false, default: "google_oauth2"
      t.string :uid,      null: false, default: ""
      t.string :display_name, null: false, default: ""
      t.string :avatar_url

      t.timestamps null: false
    end

    add_index :users, :email,            unique: true
    add_index :users, [ :provider, :uid ], unique: true
  end
end

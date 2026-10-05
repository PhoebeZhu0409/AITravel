# frozen_string_literal: true

class CreateTravellerNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :traveller_notes do |t|
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false, default: ""

      t.timestamps
    end

    add_index :traveller_notes, [:user_id, :created_at]
  end
end

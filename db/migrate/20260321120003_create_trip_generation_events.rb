# frozen_string_literal: true

class CreateTripGenerationEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :trip_generation_events do |t|
      t.references :user, null: false, foreign_key: true
      t.references :trip, null: true, foreign_key: { on_delete: :nullify }

      t.timestamps
    end

    add_index :trip_generation_events, %i[user_id created_at], name: "index_trip_generation_events_on_user_and_created"
  end
end

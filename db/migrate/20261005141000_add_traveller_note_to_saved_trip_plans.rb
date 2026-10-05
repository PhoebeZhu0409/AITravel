# frozen_string_literal: true

class AddTravellerNoteToSavedTripPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :saved_trip_plans, :traveller_note, :text, null: false, default: ""
    drop_table :traveller_notes, if_exists: true
  end
end

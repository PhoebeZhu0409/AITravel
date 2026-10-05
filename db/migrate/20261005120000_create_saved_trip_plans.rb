# frozen_string_literal: true

class CreateSavedTripPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :saved_trip_plans do |t|
      t.references :user, null: false, foreign_key: true
      t.references :trip_plan, null: false, foreign_key: true

      t.timestamps
    end

    add_index :saved_trip_plans, %i[user_id trip_plan_id], unique: true
  end
end

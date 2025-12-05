class CreateTripPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :trip_plans do |t|
      t.integer :trip_id
      t.string :trip_plan
      t.time :start_time
      t.time :end_time
      t.date :date
      t.string :plan_location
      t.text :plan_details

      t.timestamps
    end
  end
end

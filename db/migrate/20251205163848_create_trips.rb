class CreateTrips < ActiveRecord::Migration[8.0]
  def change
    create_table :trips do |t|
      t.string :trip_name
      t.string :trip_location
      t.integer :trip_duration_days
      t.string :trip_start_date
      t.text :trip_notes

      t.timestamps
    end
  end
end

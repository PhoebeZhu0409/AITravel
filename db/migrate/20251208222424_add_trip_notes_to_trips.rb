class AddTripNotesToTrips < ActiveRecord::Migration[8.0]
  def change
    add_column :trips, :trip_notes, :text
  end
end

class ChangeTripStartDateToDateInTrips < ActiveRecord::Migration[7.0]
  def change
    change_column :trips,
                  :trip_start_date,
                  :date,
                  using: 'trip_start_date::date'
  end
end

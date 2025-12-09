class ReallyRemoveMyPreferenceFromTrips < ActiveRecord::Migration[8.0]
  def change
    remove_column :trips, :my_preference, :text
  end
end

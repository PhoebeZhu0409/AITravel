class AddMyPreferenceToTrips < ActiveRecord::Migration[8.0]
  def change
    add_column :trips, :my_preference, :text
  end
end

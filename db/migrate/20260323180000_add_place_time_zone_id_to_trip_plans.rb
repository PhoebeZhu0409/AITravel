# frozen_string_literal: true

class AddPlaceTimeZoneIdToTripPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :trip_plans, :place_time_zone_id, :string
  end
end

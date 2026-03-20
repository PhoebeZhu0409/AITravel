# frozen_string_literal: true

class AddPlaceCoordinatesToTripPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :trip_plans, :place_latitude, :decimal, precision: 10, scale: 7
    add_column :trip_plans, :place_longitude, :decimal, precision: 10, scale: 7
  end
end

# frozen_string_literal: true

class AddPlaceGoogleIdToTripPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :trip_plans, :place_google_id, :string
  end
end

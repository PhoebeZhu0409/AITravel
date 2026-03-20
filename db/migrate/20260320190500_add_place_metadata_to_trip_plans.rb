# frozen_string_literal: true

class AddPlaceMetadataToTripPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :trip_plans, :place_rating, :decimal, precision: 3, scale: 2
    add_column :trip_plans, :place_user_ratings_total, :integer
    add_column :trip_plans, :place_display_name, :string
  end
end

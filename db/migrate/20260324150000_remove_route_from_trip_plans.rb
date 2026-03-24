# frozen_string_literal: true

class RemoveRouteFromTripPlans < ActiveRecord::Migration[8.0]
  def change
    remove_column :trip_plans, :route, :text
  end
end

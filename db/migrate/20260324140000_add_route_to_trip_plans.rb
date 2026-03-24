# frozen_string_literal: true

class AddRouteToTripPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :trip_plans, :route, :text
  end
end

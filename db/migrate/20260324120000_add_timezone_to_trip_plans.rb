# frozen_string_literal: true

class AddTimezoneToTripPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :trip_plans, :timezone, :string
  end
end

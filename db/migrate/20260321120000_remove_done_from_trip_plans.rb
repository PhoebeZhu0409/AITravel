# frozen_string_literal: true

class RemoveDoneFromTripPlans < ActiveRecord::Migration[8.0]
  def change
    remove_column :trip_plans, :done, :boolean, default: false, null: false
  end
end

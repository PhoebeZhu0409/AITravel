class AddDoneToTripPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :trip_plans, :done, :boolean, default: false, null: false
  end
end

class AddUserIdToTripPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :trip_plans, :user_id, :integer
  end
end

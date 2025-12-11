class AddPlanBriefToTripPlans < ActiveRecord::Migration[8.0]
  def change
    add_column :trip_plans, :plan_brief, :string
  end
end

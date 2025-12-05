# == Schema Information
#
# Table name: trip_plans
#
#  id            :bigint           not null, primary key
#  date          :date
#  end_time      :time
#  plan_details  :text
#  plan_location :string
#  start_time    :time
#  trip_plan     :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  trip_id       :integer
#
class TripPlan < ApplicationRecord
  belongs_to :trip, required: true, class_name: "Trip", foreign_key: "trip_id"
end

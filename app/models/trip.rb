# == Schema Information
#
# Table name: trips
#
#  id                 :bigint           not null, primary key
#  trip_duration_days :integer
#  trip_location      :string
#  trip_name          :string
#  trip_notes         :text
#  trip_start_date    :date
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
class Trip < ApplicationRecord
  has_many  :trip_plans, class_name: "TripPlan", foreign_key: "trip_id", dependent: :destroy


  validates :trip_duration_days, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :trip_location, presence: true
  validates :trip_name, presence: true
  validates :trip_start_date, presence: true, comparison: { greater_than: Date.today, message: "cannot be in the past"}
  
end

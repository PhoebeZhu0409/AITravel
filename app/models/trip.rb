# == Schema Information
#
# Table name: trips
#
#  id                 :bigint           not null, primary key
#  trip_duration_days :integer
#  trip_location      :string
#  trip_name          :string
#  trip_notes         :text
#  trip_start_date    :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
class Trip < ApplicationRecord
  has_many  :trip_plans, class_name: "TripPlan", foreign_key: "trip_id", dependent: :destroy


  validates :trip_duration_days, presence: true
  validates :trip_location, presence: true
  validates :trip_name, presence: true
  validates :trip_start_date, presence: true
end

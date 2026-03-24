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
#  user_id            :integer
#
class Trip < ApplicationRecord
  has_many  :trip_plans, class_name: "TripPlan", foreign_key: "trip_id", dependent: :destroy
  has_many  :trip_generation_events, dependent: :nullify
  belongs_to :user, required: true, class_name: "User", foreign_key: "user_id"

  # Google Places photo for trip_location; cached so the home “Future trips” hero does not call APIs each visit.
  has_one_attached :location_hero

  validates :trip_duration_days, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :trip_location, presence: true
  validates :trip_name, presence: true
  validates :trip_start_date, presence: true, comparison: { greater_than: Date.today, message: "cannot be in the past"}
  
end

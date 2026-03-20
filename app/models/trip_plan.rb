# == Schema Information
#
# Table name: trip_plans
#
#  id                       :bigint           not null, primary key
#  date                     :date
#  done                     :boolean
#  end_time                 :time
#  place_display_name       :string
#  place_latitude           :decimal(10, 7)
#  place_longitude          :decimal(10, 7)
#  place_rating             :decimal(3, 2)
#  place_user_ratings_total :integer
#  plan_brief               :string
#  plan_details             :text
#  plan_location            :string
#  start_time               :time
#  trip_plan                :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  trip_id                  :integer
#  user_id                  :integer
#
class TripPlan < ApplicationRecord
  belongs_to :trip, required: true, class_name: "Trip", foreign_key: "trip_id"
  belongs_to :user, required: true, class_name: "User", foreign_key: "user_id"

  has_one_attached :place_thumbnail

  # Populated once at agenda generation; show page skips client-side Places if true.
  def google_place_cached?
    place_thumbnail.attached? ||
      place_rating.present? ||
      place_user_ratings_total.present? ||
      place_display_name.present?
  end
end

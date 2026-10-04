# == Schema Information
#
# Table name: trip_plans
#
#  id                       :bigint           not null, primary key
#  date                     :date
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
#  timezone                 :string
#  trip_plan                :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  place_time_zone_id       :string
#  trip_id                  :integer
#  user_id                  :integer
#
class TripPlan < ApplicationRecord
  belongs_to :trip, required: true, class_name: "Trip", foreign_key: "trip_id"
  belongs_to :user, required: true, class_name: "User", foreign_key: "user_id"

  has_one_attached :place_thumbnail

  # Same URL as the agenda card link (show template); use in PDF so links match the website.
  def google_maps_search_url
    return if plan_location.blank?

    q = ERB::Util.url_encode(plan_location.to_s)
    "https://www.google.com/maps/search/?api=1&query=#{q}"
  end

  # Opens Uber's website in a new tab with drop-off prefilled.
  def uber_dropoff_url
    return if plan_location.blank?

    UberDropoffUrl.universal(**uber_dropoff_kwargs)
  end

  def uber_go_url
    uber_dropoff_url
  end

  def uber_dropoff_app_url
    return if plan_location.blank?

    UberDropoffUrl.app(**uber_dropoff_kwargs)
  end

  def uber_dropoff_mobile_url
    return if plan_location.blank?

    UberDropoffUrl.universal(**uber_dropoff_kwargs)
  end

  # Populated once at agenda generation; show page skips client-side Places if true.
  def google_place_cached?
    place_thumbnail.attached? ||
      place_rating.present? ||
      place_user_ratings_total.present? ||
      place_display_name.present?
  end

  private

  def uber_dropoff_kwargs
    {
      address: plan_location,
      name: uber_nickname,
      lat: place_latitude,
      lng: place_longitude
    }
  end

  def uber_nickname
    place_display_name.presence || plan_location.to_s.split(",").first.to_s.strip
  end
end

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

  # Opens Uber with drop-off prefilled — mobile app, mobile web, or desktop browser.
  def uber_dropoff_url
    uber_dropoff_web_url
  end

  # Prefer in native Uber app on phones (pickup = current location).
  def uber_dropoff_mobile_url
    return if plan_location.blank?

    nickname = place_display_name.presence || plan_location.split(",").first.to_s.strip
    query = {
      "action" => "setPickup",
      "pickup" => "my_location",
      "dropoff[formatted_address]" => plan_location.to_s
    }

    if place_latitude.present? && place_longitude.present?
      query["dropoff[latitude]"] = place_latitude.to_f
      query["dropoff[longitude]"] = place_longitude.to_f
    end

    query["dropoff[nickname]"] = nickname if nickname.present?

    params = query.map { |key, value| "#{ERB::Util.url_encode(key)}=#{ERB::Util.url_encode(value.to_s)}" }.join("&")
    "https://m.uber.com/ul/?#{params}"
  end

  # Populated once at agenda generation; show page skips client-side Places if true.
  def google_place_cached?
    place_thumbnail.attached? ||
      place_rating.present? ||
      place_user_ratings_total.present? ||
      place_display_name.present?
  end

  private

  def uber_dropoff_web_url
    return if plan_location.blank?

    nickname = place_display_name.presence || plan_location.split(",").first.to_s.strip

    if place_latitude.present? && place_longitude.present?
      drop = {
        "latitude" => place_latitude.to_f,
        "longitude" => place_longitude.to_f,
        "addressLine1" => nickname.presence || plan_location.to_s,
        "addressLine2" => plan_location.to_s
      }
      drop_param = ERB::Util.url_encode(drop.to_json)
      return "https://m.uber.com/looking?drop[0]=#{drop_param}"
    end

    query = {
      "action" => "setPickup",
      "dropoff[formatted_address]" => plan_location.to_s
    }
    query["dropoff[nickname]"] = nickname if nickname.present?

    params = query.map { |key, value| "#{ERB::Util.url_encode(key)}=#{ERB::Util.url_encode(value.to_s)}" }.join("&")
    "https://m.uber.com/ul/?#{params}"
  end
end

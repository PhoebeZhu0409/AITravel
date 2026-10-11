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
#  place_google_id          :string
#  place_time_zone_id       :string
#  trip_id                  :integer
#  user_id                  :integer
#
class TripPlan < ApplicationRecord
  belongs_to :trip, required: true, class_name: "Trip", foreign_key: "trip_id"
  belongs_to :user, required: true, class_name: "User", foreign_key: "user_id"

  has_many :saved_trip_plans, dependent: :destroy
  has_one_attached :place_thumbnail

  # Same URL as the agenda card link (show template); use in PDF so links match the website.
  def google_maps_search_url
    return if plan_location.blank?

    q = ERB::Util.url_encode(plan_location.to_s)
    "https://www.google.com/maps/search/?api=1&query=#{q}"
  end

  # Opens Uber via /go/uber so we can attach a Google Place id, then 303 to /go/pickup.
  def uber_dropoff_url
    return if plan_location.blank?

    "/go/uber?#{uber_go_params.to_query}"
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

  # True only when the photo blob is actually on disk (Render local storage can drop files).
  def place_thumbnail_available?
    return false unless place_thumbnail.attached?

    place_thumbnail.blob.service.exist?(place_thumbnail.blob.key)
  rescue StandardError => e
    Rails.logger.warn("[ActiveStorage] place thumbnail check failed: #{e.class} #{e.message}")
    false
  end

  # Wall-clock components for a Postgres `time` column (destination local time, not device TZ).
  def wall_clock_hms(time_attr)
    value = public_send(time_attr)
    return nil if value.blank?

    t = value.utc
    [t.hour, t.min, t.sec]
  end

  # Populated once at agenda generation; show page skips client-side Places if true.
  def google_place_cached?
    place_thumbnail_available? ||
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
      lng: place_longitude,
      place_id: place_google_id
    }
  end

  def uber_go_params
    h = { address: plan_location }
    h[:name] = uber_nickname if uber_nickname.present?
    if place_latitude.present? && place_longitude.present?
      h[:lat] = format("%.7f", place_latitude.to_f)
      h[:lng] = format("%.7f", place_longitude.to_f)
    end
    h[:place_id] = place_google_id if place_google_id.present?
    h[:plan_id] = id
    h
  end

  def uber_nickname
    place_display_name.presence || plan_location.to_s.split(",").first.to_s.strip
  end
end

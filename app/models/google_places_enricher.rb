# frozen_string_literal: true

require "net/http"
require "json"
require "stringio"
require "securerandom"

# One-time server-side fetch when a TripPlan is created (agenda generation).
# Stores rating, review count, display name, and photo in DB / Active Storage
# so the trip show page does not call Google Places on every refresh.
#
# Uses the Places Web Service (Find Place From Text). Your GOOGLE_MAPS_API_KEY must
# allow server-side use: e.g. "IP addresses" for your host, or none for local dev.
# A key restricted to "HTTP referrers" only may work in the browser but fail here.
class GooglePlacesEnricher
  FIND_PLACE_URL = "https://maps.googleapis.com/maps/api/place/findplacefromtext/json"
  PHOTO_URL = "https://maps.googleapis.com/maps/api/place/photo"
  TIMEZONE_URL = "https://maps.googleapis.com/maps/api/timezone/json"

  class << self
    def enrich_trip_plan(trip_plan)
      key = ENV.fetch("GOOGLE_MAPS_API_KEY", "").to_s.strip
      return if key.blank?

      query = trip_plan.plan_location.to_s.strip
      return if query.blank?

      data = find_place_json(query, key)
      return unless data
      return unless data["status"] == "OK"

      cand = data["candidates"]&.first
      return unless cand

      trip_plan.place_display_name = cand["name"] if cand["name"].present?
      trip_plan.place_rating = cand["rating"] if cand.key?("rating")
      trip_plan.place_user_ratings_total = cand["user_ratings_total"] if cand.key?("user_ratings_total")

      lat = cand.dig("geometry", "location", "lat")
      lng = cand.dig("geometry", "location", "lng")
      if lat.present? && lng.present?
        trip_plan.place_latitude = lat
        trip_plan.place_longitude = lng
        tz_id = fetch_time_zone_id(lat, lng, trip_plan.date, key)
        trip_plan.place_time_zone_id = tz_id if tz_id.present?
      end

      photo_ref = cand.dig("photos", 0, "photo_reference")
      if photo_ref.present?
        attach_photo(trip_plan, photo_ref, key)
      end

      trip_plan.save!
    rescue StandardError => e
      Rails.logger.warn("[GooglePlacesEnricher] #{e.class}: #{e.message}")
      # Leave plan row usable without cache
    end

    # IANA id (e.g. "America/New_York") for the user's trip destination string from the form.
    # Uses Find Place + Time Zone API (same key as enrich). reference_date is used for the timezone request.
    def timezone_id_for_location(location_query, reference_date)
      key = ENV.fetch("GOOGLE_MAPS_API_KEY", "").to_s.strip
      return nil if key.blank?

      query = location_query.to_s.strip
      return nil if query.blank? || reference_date.blank?

      data = find_place_json(query, key)
      return nil unless data && data["status"] == "OK"

      cand = data["candidates"]&.first
      return nil unless cand

      lat = cand.dig("geometry", "location", "lat")
      lng = cand.dig("geometry", "location", "lng")
      return nil unless lat.present? && lng.present?

      fetch_time_zone_id(lat, lng, reference_date, key)
    end

    private

    # IANA zone id, e.g. "America/New_York" — used for agenda start-time abbreviations (EST, etc.).
    def fetch_time_zone_id(lat, lng, date, key)
      return if date.blank?

      ts = Time.utc(date.year, date.month, date.day, 12, 0, 0).to_i
      uri = URI(TIMEZONE_URL)
      uri.query = URI.encode_www_form(
        location: "#{lat},#{lng}",
        timestamp: ts,
        key: key
      )
      res = http_get_follow(uri)
      return unless res.is_a?(Net::HTTPSuccess)

      data = JSON.parse(res.body)
      return unless data["status"] == "OK"

      data["timeZoneId"].presence
    rescue JSON::ParserError => e
      Rails.logger.warn("[GooglePlacesEnricher] timezone JSON: #{e.message}")
      nil
    end

    def find_place_json(query, key)
      uri = URI(FIND_PLACE_URL)
      uri.query = URI.encode_www_form(
        input: query,
        inputtype: "textquery",
        fields: "name,rating,user_ratings_total,photos,geometry",
        key: key
      )
      res = http_get_follow(uri)
      return unless res.is_a?(Net::HTTPSuccess)

      JSON.parse(res.body)
    rescue JSON::ParserError => e
      Rails.logger.warn("[GooglePlacesEnricher] JSON parse: #{e.message}")
      nil
    end

    def attach_photo(trip_plan, photo_ref, key)
      uri = URI(PHOTO_URL)
      uri.query = URI.encode_www_form(maxwidth: 800, photo_reference: photo_ref, key: key)
      res = http_get_follow(uri)
      return unless res.is_a?(Net::HTTPSuccess)

      body = res.body
      return if body.blank?

      ctype = res.content_type.to_s.split(";").first.presence || "image/jpeg"
      ext = if ctype.include?("png")
              "png"
            elsif ctype.include?("webp")
              "webp"
            else
              "jpg"
            end

      trip_plan.place_thumbnail.attach(
        io: StringIO.new(body),
        filename: "place-#{trip_plan.id}-#{SecureRandom.hex(4)}.#{ext}",
        content_type: ctype
      )
    end

    # Place Photo often 302-redirects to googleusercontent.com — follow a few hops.
    def http_get_follow(uri, redirect_limit = 8)
      current = uri.is_a?(URI) ? uri : URI.parse(uri.to_s)

      redirect_limit.times do
        res = Net::HTTP.start(current.host, current.port, use_ssl: current.scheme == "https") do |http|
          http.get(current.request_uri)
        end

        case res
        when Net::HTTPSuccess
          return res
        when Net::HTTPRedirection
          loc = res["location"]
          return nil if loc.blank?

          current = URI.join(current.to_s, loc)
        else
          Rails.logger.warn("[GooglePlacesEnricher] HTTP #{res.code} for #{current.host}")
          return nil
        end
      end

      nil
    end
  end
end

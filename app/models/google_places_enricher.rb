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
  # Bias venue search toward the trip destination (meters).
  LOCATION_BIAS_RADIUS_M = 50_000

  class << self
    def enrich_trip_plan(trip_plan)
      key = ENV.fetch("GOOGLE_MAPS_API_KEY", "").to_s.strip
      return if key.blank?

      query = trip_plan.plan_location.to_s.strip
      return if query.blank?

      bias = destination_coordinates_for(trip_plan.trip, key)
      data = find_place_json(query, key, location_bias: bias)
      return unless data
      return unless data["status"] == "OK"

      cand = pick_best_candidate(query, data["candidates"])
      return unless cand

      trip_plan.place_display_name = cand["name"] if cand["name"].present?
      trip_plan.place_google_id = cand["place_id"] if cand["place_id"].present?
      trip_plan.place_rating = cand["rating"] if cand.key?("rating")
      trip_plan.place_user_ratings_total = cand["user_ratings_total"] if cand.key?("user_ratings_total")

      lat = cand.dig("geometry", "location", "lat")
      lng = cand.dig("geometry", "location", "lng")
      if lat.present? && lng.present?
        trip_plan.place_latitude = lat
        trip_plan.place_longitude = lng
        tz_id = fetch_time_zone_id(lat, lng, trip_plan.date, key)
        if tz_id.present?
          trip_plan.place_time_zone_id = tz_id
          tz = Time.find_zone(tz_id)
          if tz && trip_plan.date.present?
            d = trip_plan.date
            trip_plan.timezone = tz.local(d.year, d.month, d.day, 12, 0, 0).strftime("%Z").presence
          end
        end
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

    # One-time hero image for the trip’s destination (Find Place + Photo → Active Storage).
    def enrich_trip_destination!(trip)
      key = ENV.fetch("GOOGLE_MAPS_API_KEY", "").to_s.strip
      return if key.blank?

      query = trip.trip_location.to_s.strip
      return if query.blank?

      data = find_place_json(query, key)
      return unless data && data["status"] == "OK"

      cand = data["candidates"]&.first
      return unless cand

      photo_ref = cand.dig("photos", 0, "photo_reference")
      return if photo_ref.blank?

      trip.location_hero.purge if trip.location_hero.attached?

      attach_location_hero_from_photo_ref(trip, photo_ref, key)
      trip.save!
    rescue StandardError => e
      Rails.logger.warn("[GooglePlacesEnricher] trip destination hero: #{e.class}: #{e.message}")
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

    # Look up Google Place id + geometry for Uber dropoff links.
    def find_place_details(query, location_bias: nil)
      key = ENV.fetch("GOOGLE_MAPS_API_KEY", "").to_s.strip
      return nil if key.blank?

      q = query.to_s.strip
      return nil if q.blank?

      data = find_place_json(q, key, location_bias: location_bias)
      return nil unless data && data["status"] == "OK"

      cand = pick_best_candidate(q, data["candidates"])
      return nil unless cand

      {
        place_id: cand["place_id"].presence,
        name: cand["name"].presence,
        formatted_address: cand["formatted_address"].presence,
        lat: cand.dig("geometry", "location", "lat"),
        lng: cand.dig("geometry", "location", "lng")
      }.compact
    rescue StandardError => e
      Rails.logger.warn("[GooglePlacesEnricher] find_place_details: #{e.class}: #{e.message}")
      nil
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

    def find_place_json(query, key, location_bias: nil)
      params = {
        input: query,
        inputtype: "textquery",
        fields: "place_id,name,formatted_address,rating,user_ratings_total,photos,geometry",
        key: key
      }
      if location_bias
        params[:locationbias] = "circle:#{LOCATION_BIAS_RADIUS_M}@#{location_bias[:lat]},#{location_bias[:lng]}"
      end

      uri = URI(FIND_PLACE_URL)
      uri.query = URI.encode_www_form(params)
      res = http_get_follow(uri)
      return unless res.is_a?(Net::HTTPSuccess)

      JSON.parse(res.body)
    rescue JSON::ParserError => e
      Rails.logger.warn("[GooglePlacesEnricher] JSON parse: #{e.message}")
      nil
    end

    # Cached per trip during a single request (e.g. batch enrich after agenda generation).
    def destination_coordinates_for(trip, key)
      return nil if trip.blank?

      cache = destination_coordinates_cache
      return cache[trip.id] if cache.key?(trip.id)

      query = trip.trip_location.to_s.strip
      coords = nil
      if query.present?
        data = find_place_json(query, key)
        if data && data["status"] == "OK"
          cand = data["candidates"]&.first
          lat = cand&.dig("geometry", "location", "lat")
          lng = cand&.dig("geometry", "location", "lng")
          coords = { lat: lat, lng: lng } if lat.present? && lng.present?
        end
      end

      cache[trip.id] = coords
      coords
    end

    def destination_coordinates_cache
      Thread.current[:google_places_destination_coords] ||= {}
    end

    def pick_best_candidate(query, candidates)
      return nil if candidates.blank?
      return candidates.first if candidates.size == 1

      expected = normalize_place_name(query.split(",").first)

      candidates.max_by do |c|
        name = normalize_place_name(c["name"])
        score = 0
        score += 100 if name == expected
        score += 50 if expected.present? && name.include?(expected)
        score += 25 if expected.present? && expected.include?(name)
        extra = name.split - expected.split
        score -= extra.size * 10
        score + [c["user_ratings_total"].to_i, 0].max / 100
      end
    end

    def normalize_place_name(str)
      str.to_s.downcase.gsub(/[^a-z0-9\s]/, " ").squish
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

    def attach_location_hero_from_photo_ref(trip, photo_ref, key)
      uri = URI(PHOTO_URL)
      uri.query = URI.encode_www_form(maxwidth: 1200, photo_reference: photo_ref, key: key)
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

      trip.location_hero.attach(
        io: StringIO.new(body),
        filename: "trip-#{trip.id}-destination-#{SecureRandom.hex(4)}.#{ext}",
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

# frozen_string_literal: true

# Backfill destination hero when Active Storage says attached but the file is missing (e.g. Render redeploy).
class EnsureTripLocationHeroJob < ApplicationJob
  queue_as :default

  def perform(trip_id)
    trip = Trip.find_by(id: trip_id)
    return unless trip
    return if trip.location_hero_available?

    skip_key = "trip_hero_skip/#{trip.id}"
    return if Rails.cache.read(skip_key)

    GooglePlacesEnricher.enrich_trip_destination!(trip)
    return if trip.reload.location_hero_available?

    Rails.cache.write(skip_key, true, expires_in: 7.days)
  end
end

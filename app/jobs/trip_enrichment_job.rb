# frozen_string_literal: true

# Photos, ratings, and map pins — after the user is redirected to the trip page.
class TripEnrichmentJob < ApplicationJob
  queue_as :default

  def perform(trip_id)
    trip = Trip.find_by(id: trip_id)
    return unless trip

    unless trip.location_hero.attached? && blob_stored?(trip.location_hero)
      GooglePlacesEnricher.enrich_trip_destination!(trip)
    end

    trip.trip_plans.find_each do |trip_plan|
      GooglePlacesEnricher.enrich_trip_plan(trip_plan)
    end
  end

  private

  def blob_stored?(attachment)
    return false unless attachment.attached?

    attachment.blob.service.exist?(attachment.blob.key)
  rescue StandardError
    false
  end
end

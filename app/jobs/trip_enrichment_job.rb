# frozen_string_literal: true

# Photos, ratings, and map pins — after the user is redirected to the trip page.
class TripEnrichmentJob < ApplicationJob
  queue_as :default

  def perform(trip_id)
    trip = Trip.find_by(id: trip_id)
    return unless trip

    GooglePlacesEnricher.enrich_trip_destination!(trip)

    trip.trip_plans.find_each do |trip_plan|
      GooglePlacesEnricher.enrich_trip_plan(trip_plan)
    end
  end
end

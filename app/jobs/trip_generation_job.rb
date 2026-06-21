# frozen_string_literal: true

# AI + Google enrichment — must not run inside the web request (Render times out ~30s).
class TripGenerationJob < ApplicationJob
  queue_as :default

  def perform(trip_id)
    trip = Trip.find_by(id: trip_id)
    return unless trip

    generator = TripAgendaGenerator.new(trip)
    generator.generate_plans!
    trip.user.record_trip_generation!(trip: trip)
    generator.enrich!
  rescue JSON::ParserError => e
    Rails.logger.error("Trip #{trip_id} JSON parse failed: #{e.message}")
    Rails.error.report(e, handled: true, context: { trip_id: trip_id })
  rescue StandardError => e
    Rails.logger.error(
      "Trip #{trip_id} generation failed: #{e.class} - #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}"
    )
    Rails.error.report(e, handled: true, context: { trip_id: trip_id })
  end
end

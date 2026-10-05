# frozen_string_literal: true

# Backfill a missing Google Places photo onto a trip plan (saved spots / lost blobs).
class EnsurePlaceThumbnailJob < ApplicationJob
  queue_as :default

  def perform(trip_plan_id)
    trip_plan = TripPlan.find_by(id: trip_plan_id)
    return unless trip_plan
    return if trip_plan.place_thumbnail_available?

    skip_key = "place_thumb_skip/#{trip_plan.id}"
    return if Rails.cache.read(skip_key)

    GooglePlacesEnricher.ensure_place_thumbnail!(trip_plan)
    return if trip_plan.reload.place_thumbnail_available?

    Rails.cache.write(skip_key, true, expires_in: 7.days)
  end
end

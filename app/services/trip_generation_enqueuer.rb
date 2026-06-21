# frozen_string_literal: true

# Runs trip generation outside the web request without relying on Solid Queue workers.
# On a single Render dyno, solid_queue + Puma plugin is unreliable; async adapter can
# also fail to pick up jobs. A background thread with perform_now is dependable.
class TripGenerationEnqueuer
  ATTEMPT_COOLDOWN = 2.minutes

  def self.call(trip_id)
    mark_attempt!(trip_id)

    if Rails.env.test?
      TripGenerationJob.perform_now(trip_id)
      return
    end

    Thread.new do
      Rails.application.executor.wrap do
        Rails.logger.info("TripGenerationEnqueuer: starting generation for trip #{trip_id}")
        TripGenerationJob.perform_now(trip_id)
      end
    end
  end

  # Re-run generation when the trip page loads with an empty agenda (stuck or failed job).
  def self.retry_if_needed!(trip)
    return if trip.trip_plans.any?

    last_attempt = Rails.cache.read(attempt_key(trip.id))
    return if last_attempt && last_attempt > ATTEMPT_COOLDOWN.ago

    call(trip.id)
  end

  def self.mark_attempt!(trip_id)
    Rails.cache.write(attempt_key(trip_id), Time.current, expires_in: 1.hour)
  end

  def self.attempt_key(trip_id)
    "trip_gen_attempt:#{trip_id}"
  end
  private_class_method :mark_attempt!, :attempt_key
end

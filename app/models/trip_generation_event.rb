# frozen_string_literal: true

# One row per successful AI itinerary generation (new trip or rebuild).
# Used to enforce regular-account limits; premium users do not create rows.
# == Schema Information
#
# Table name: trip_generation_events
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  trip_id    :bigint
#  user_id    :bigint           not null
#
# Indexes
#
#  index_trip_generation_events_on_trip_id           (trip_id)
#  index_trip_generation_events_on_user_and_created  (user_id,created_at)
#  index_trip_generation_events_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (trip_id => trips.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id)
#
class TripGenerationEvent < ApplicationRecord
  belongs_to :user
  belongs_to :trip, optional: true
end

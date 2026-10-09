# == Schema Information
#
# Table name: trips
#
#  id                 :bigint           not null, primary key
#  showcase_slug      :string
#  trip_duration_days :integer
#  trip_location      :string
#  trip_name          :string
#  trip_notes         :text
#  trip_start_date    :date
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  user_id            :integer
#
# Indexes
#
#  index_trips_on_showcase_slug  (showcase_slug) UNIQUE WHERE (showcase_slug IS NOT NULL)
#
class Trip < ApplicationRecord
  SHOWCASE_SLUGS = %w[madrid new_york].freeze
  MAX_TRIP_DURATION_DAYS = 21
  LONG_TRIP_WARNING_DAYS = 10

  has_many  :trip_plans, class_name: "TripPlan", foreign_key: "trip_id", dependent: :destroy
  has_many  :trip_generation_events, dependent: :nullify
  belongs_to :user, required: true, class_name: "User", foreign_key: "user_id"

  # Google Places photo for trip_location; cached so the home “Future trips” hero does not call APIs each visit.
  has_one_attached :location_hero

  validates :trip_duration_days, presence: true,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_TRIP_DURATION_DAYS }
  validates :trip_location, presence: true
  validates :trip_name, presence: true
  validates :trip_start_date, presence: true, comparison: { greater_than_or_equal_to: -> { Date.current }, message: "cannot be in the past" }
  validates :showcase_slug, inclusion: { in: SHOWCASE_SLUGS }, allow_nil: true
  validates :showcase_slug, uniqueness: true, allow_nil: true

  scope :showcase, -> { where.not(showcase_slug: nil) }

  # Future while any trip day remains (last day >= today in app time zone).
  scope :future_trips, lambda { |as_of = Date.current|
    where("trip_start_date + (trip_duration_days - 1) >= ?", as_of)
  }

  scope :past_trips, lambda { |as_of = Date.current|
    where("trip_start_date + (trip_duration_days - 1) < ?", as_of)
  }

  def trip_end_date
    return unless trip_start_date.present? && trip_duration_days.present?

    trip_start_date + trip_duration_days.days - 1.day
  end

  def location_hero_available?
    return false unless location_hero.attached?

    location_hero.blob.service.exist?(location_hero.blob.key)
  rescue StandardError => e
    Rails.logger.warn("[ActiveStorage] location hero check failed: #{e.class} #{e.message}")
    false
  end
end

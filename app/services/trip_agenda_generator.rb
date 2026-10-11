# frozen_string_literal: true

# AI itinerary + Google Places enrichment — runs in TripGenerationJob (not in the web request).
class TripAgendaGenerator
  def initialize(trip)
    @trip = trip
  end

  def call!
    generate_plans!
    enrich!
  end

  def generate_plans!
    plan_hash = generate_ai_plan_for(@trip)
    replace_trip_plans_from_ai!(plan_hash)
  end

  def enrich!
    enrich_destination_hero!
    @trip.trip_plans.find_each { |tp| GooglePlacesEnricher.enrich_trip_plan(tp) }
    apply_destination_time_zone_to_plans!
  end

  private

  attr_reader :trip

  def generate_ai_plan_for(the_trip)
    chat = AI::Chat.new
    chat.model = ENV.fetch("OPENAI_PLANNING_MODEL", "gpt-4.1-mini")
    chat.system(ai_planning_prompt)
    chat.user(build_user_input(the_trip))

    response = chat.generate!
    raw = response[:content].to_s

    JSON.parse(raw, symbolize_names: true)
  end

  def build_user_input(the_trip)
    segments = itinerary_segments_for(the_trip)
    notes = freeform_trip_notes(the_trip.trip_notes)

    <<~TEXT.squish
      #{segments}
      Overall trip window: #{the_trip.trip_start_date} through #{the_trip.trip_end_date} (#{the_trip.trip_duration_days} days).
      Notes: #{notes}
      Produce the itinerary JSON as specified. No prose outside JSON.
    TEXT
  end

  def itinerary_segments_for(the_trip)
    primary = TripLegNotes.primary_from_notes(the_trip.trip_notes)
    second = TripLegNotes.second_from_notes(the_trip.trip_notes)

    if primary && second
      <<~SEG.squish
        Multi-city trip. Leg 1: #{primary.location} from #{primary.start_date} through #{primary.end_date}.
        Leg 2: #{second.location} from #{second.start_date} through #{second.end_date}.
        Plan each day in the correct city for its date range.
      SEG
    elsif second
      <<~SEG.squish
        Primary destination: #{the_trip.trip_location} from #{the_trip.trip_start_date} through #{the_trip.trip_end_date}.
        Second destination: #{second.location} from #{second.start_date} through #{second.end_date}.
        Plan each day in the correct city for its date range.
      SEG
    else
      "Destination: #{the_trip.trip_location}. Start date: #{the_trip.trip_start_date}. Duration: #{the_trip.trip_duration_days} days."
    end
  end

  def freeform_trip_notes(notes)
    notes.to_s.split(" ; ").map(&:strip).reject do |part|
      part.start_with?(TripLegNotes::PRIMARY_PREFIX) ||
        part.start_with?(TripLegNotes::SECOND_PREFIX)
    end.join(" ; ")
  end

  def ai_planning_prompt
    <<~SYS
      You output ONLY valid JSON (no markdown, no code fences, no commentary).

      Shape:
      {"days":[{"date":"YYYY-MM-DD","items":[{"start_time":"HH:MM","end_time":"HH:MM","activity":"string","plan_brief":"string","location":"string","commute":"string"}]}]}

      Rules:
      - Cover every calendar day from the user's start date through the full trip duration; one object per day in "days".
      - Each day: choose a varied mix of the destination’s most worthwhile things to do and experience, prioritizing must-dos and standout local experiences rather than any particular type of activity.
      - The user message includes a "Notes:" line (form + textarea; any wording). Ignore noise or off-topic text. Prioritize normal destination must-sees and a balanced trip; use Notes only as a light preference layer on top.
      - If Notes mention a hobby, food preference, or similar, reflect it sparingly: a few fitting stops or occasional slots—not the same idea on most days, and never a single-topic trip unless the user explicitly demands it (only that, every day, whole trip about X).
      - start_time / end_time: local time at destination, 24-hour HH:MM.
      - activity: Explaining what makes the specific place or experience distinctive or worth including; never repeat the activity or begin with an action verb. Give the most specific interesting fact about what makes it special and use historical/cultural significance when relevant. Avoid generic descriptions.
      - plan_brief: max 4 words.
      - location: venue or place name + neighborhood or area + city (enough to find on Google Maps; do not invent street numbers).
      - commute: at most ONE short sentence (how to get from the previous stop or hotel). Mention tickets/reservations only if essential before arrival.
      - Omit timezone fields; times are local to the trip destination the user gave.
      - If unknown, assume reasonably; keep text short.
      - Meals: Unless indicated otherwise, include highly recommended, must-try meal spots that fit naturally with the route and timing of the day for lunch and dinner, plus breakfast or café stops when especially worthwhile.
      - Season: infer month/season at the destination from start_date (correct hemisphere). Choose weather-appropriate activities and indoor/outdoor mix; shift timing for daylight, heat, or rain; prefer seasonal highlights (festivals, markets, nature) when they fit; avoid activities that are unsafe, closed, or impractical that month.
    SYS
  end

  def replace_trip_plans_from_ai!(plan_hash)
    plan_attrs = build_trip_plan_attrs(plan_hash)
    if plan_attrs.empty?
      raise ArgumentError, "AI itinerary contained no plan items"
    end

    ActiveRecord::Base.transaction do
      trip.trip_plans.destroy_all
      plan_attrs.each { |attrs| TripPlan.create!(attrs) }
    end
  end

  def build_trip_plan_attrs(plan_hash)
    plan_hash.fetch(:days, []).flat_map do |day|
      date = Date.parse(day[:date])

      day.fetch(:items, []).map do |item|
        location = item[:location].to_s.strip
        {
          trip: trip,
          date: date,
          start_time: parse_wall_clock_time(item[:start_time]),
          end_time: parse_wall_clock_time(item[:end_time]),
          timezone: nil,
          trip_plan: item[:activity],
          plan_brief: item[:plan_brief],
          user_id: trip.user_id,
          plan_location: location,
          plan_details: item[:commute]
        }
      end
    end
  end

  def parse_wall_clock_time(value)
    md = value.to_s.strip.match(/\A(\d{1,2}):(\d{2})(?::(\d{2}))?\z/)
    return nil unless md

    hour = md[1].to_i
    min = md[2].to_i
    sec = (md[3] || "0").to_i
    # UTC date is intentional: wall clock must be read back via .utc (see TripPlan#wall_clock_hms).
    Time.utc(2000, 1, 1, hour, min, sec)
  end

  def apply_destination_time_zone_to_plans!
    location = trip.trip_location.to_s.strip
    return if location.blank?

    missing = trip.trip_plans.select { |tp| tp.place_time_zone_id.blank? }
    return if missing.empty?

    ref_date = trip.trip_start_date || missing.filter_map(&:date).min
    return unless ref_date

    tz_id = GooglePlacesEnricher.timezone_id_for_location(location, ref_date)
    return if tz_id.blank?

    zone = Time.find_zone(tz_id)
    missing.each do |tp|
      tp.place_time_zone_id = tz_id
      if zone && tp.date.present?
        d = tp.date
        tp.timezone = zone.local(d.year, d.month, d.day, 12, 0, 0).strftime("%Z").presence
      end
      tp.save!
    end
  end

  def enrich_destination_hero!
    return if trip.trip_location.blank?

    if trip.location_hero.attached?
      blob = trip.location_hero.blob
      return if blob.service.exist?(blob.key)
    end

    GooglePlacesEnricher.enrich_trip_destination!(trip)
  end
end

# frozen_string_literal: true

# Reverses the summary string stored in trips.trip_notes (see TripsController#create / #update)
# so the rebuild form can show the same budget, people, todos, area, and free-text notes.
class RebuildFormPrefill
  BUDGET_VALUES = [
    "luxury",
    "budget friendly",
    "A mix of both luxury and budget friendly"
  ].freeze

  PEOPLE_VALUES = [
    "solo traveling",
    "traveling with my partner",
    "traveling with my friends",
    "traveling with my family"
  ].freeze

  # Must match checkbox `value` in index.html.erb / edit_trip.html.erb exactly
  TODO_VALUES = [
    "Local's favorite resturants or spots, or things to do that involves local culture ",
    "Museums, art, and history",
    "Outdoors & nature",
    "Nightlife & bars",
    "Shopping",
    "High-end restaurants and luxury experience"
  ].freeze

  PREFIX_BUDGET = "Budget wise, I want my trip to be "
  PREFIX_PEOPLE = "I am "
  PREFIX_TODO = "My trip should include a mix of these: "
  PREFIX_LIVE = "I stay near "
  SUFFIX_LIVE = "; and I can also go any other places you recommend"
  PREFIX_REQUIREMENTS = "Specifically, I have these requirements: "

  def self.from_trip_notes(notes)
    empty = { budget: nil, people: nil, todos: [], live_area: "", trip_notes: "" }
    text = notes.to_s.strip
    return empty if text.blank?

    result = empty.dup
    text.split(" ; ").map(&:strip).each do |part|
      if part.start_with?(PREFIX_BUDGET)
        val = part.delete_prefix(PREFIX_BUDGET)
        result[:budget] = val if BUDGET_VALUES.include?(val)
      elsif part.start_with?(PREFIX_PEOPLE)
        val = part.delete_prefix(PREFIX_PEOPLE)
        result[:people] = val if PEOPLE_VALUES.include?(val)
      elsif part.start_with?(PREFIX_TODO)
        raw = part.delete_prefix(PREFIX_TODO).strip
        result[:todos] = parse_todo_segment(raw)
      elsif part.start_with?(PREFIX_LIVE) && part.end_with?(SUFFIX_LIVE)
        result[:live_area] = part.delete_prefix(PREFIX_LIVE).delete_suffix(SUFFIX_LIVE)
      elsif part.start_with?(PREFIX_REQUIREMENTS)
        result[:trip_notes] = part.delete_prefix(PREFIX_REQUIREMENTS)
      end
    end

    result
  end

  def self.parse_todo_segment(raw)
    return [] if raw.blank?

    # Ruby interpolates arrays as inspect, e.g. ["A", "B"]
    if raw.start_with?("[") && raw.end_with?("]")
      inner = raw[1..-2]
      scanned = inner.scan(/"((?:\\.|[^"\\])*)"/).flatten.map { |s| s.gsub('\\"', '"').gsub("\\\\", "\\") }
      return scanned & TODO_VALUES if scanned.any?

      # Fallback: substring match for older / odd encodings
      return TODO_VALUES.select { |v| raw.include?(v) }
    end

    TODO_VALUES.select { |v| raw.include?(v) }
  end
end

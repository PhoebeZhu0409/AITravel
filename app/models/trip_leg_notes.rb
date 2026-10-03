# frozen_string_literal: true

# Encodes optional multi-city legs in trips.trip_notes (see TripsController#build_trip_summary).
class TripLegNotes
  PRIMARY_PREFIX = "Primary location: "
  SECOND_PREFIX = "Second location: "
  LEG_PATTERN = /\A(.+?) from (\d{4}-\d{2}-\d{2}) through (\d{4}-\d{2}-\d{2})\z/

  Leg = Struct.new(:location, :start_date, :end_date, keyword_init: true)

  def self.primary_from_notes(notes)
    segment = find_segment(notes, PRIMARY_PREFIX)
    parse_segment(segment)
  end

  def self.second_from_notes(notes)
    segment = find_segment(notes, SECOND_PREFIX)
    parse_segment(segment)
  end

  def self.format_leg(prefix, location, start_date, end_date)
    "#{prefix}#{location} from #{start_date} through #{end_date}"
  end

  def self.find_segment(notes, prefix)
    notes.to_s.split(" ; ").map(&:strip).find { |part| part.start_with?(prefix) }
  end

  def self.parse_segment(segment)
    return unless segment

    rest = segment.sub(/\APrimary location: |\ASecond location: /, "")
    match = LEG_PATTERN.match(rest)
    return unless match

    Leg.new(location: match[1], start_date: match[2], end_date: match[3])
  end
  private_class_method :find_segment, :parse_segment
end

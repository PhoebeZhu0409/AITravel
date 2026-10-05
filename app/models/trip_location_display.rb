# frozen_string_literal: true

# Human-readable location line for trip show (city + country only; multi-city with ";").
class TripLocationDisplay
  def self.label_for(trip)
    locations = locations_for(trip)
    return city_country_label(locations.first) if locations.length <= 1

    combine_locations(locations)
  end

  def self.locations_for(trip)
    list = [trip.trip_location.to_s.strip]
    second = TripLegNotes.second_from_notes(trip.trip_notes)
    list << second.location.to_s.strip if second&.location.present?
    list.reject(&:blank?).uniq
  end

  def self.combine_locations(locations)
    parsed = locations.filter_map { |loc| parse_city_country(loc) }
    return locations.join("; ") if parsed.length != locations.length

    countries = parsed.map { |p| p[:country] }
    if countries.uniq.size == 1
      cities = parsed.map { |p| p[:city] }
      "#{cities.join('; ')}, #{countries.first}"
    else
      parsed.map { |p| "#{p[:city]}, #{p[:country]}" }.join("; ")
    end
  end

  def self.city_country_label(location)
    parsed = parse_city_country(location)
    return location.to_s.strip unless parsed

    "#{parsed[:city]}, #{parsed[:country]}"
  end

  def self.city_country_for_plan(trip_plan)
    trip = trip_plan&.trip
    raw = destination_for_plan(trip_plan, trip)
    label = city_country_label(raw)
    label.presence || "Unknown"
  end

  def self.destination_for_plan(trip_plan, trip)
    return "" unless trip

    date = trip_plan&.date
    if date.present?
      second = TripLegNotes.second_from_notes(trip.trip_notes)
      return second.location.to_s.strip if second && date_in_leg?(date, second)

      primary = TripLegNotes.primary_from_notes(trip.trip_notes)
      return primary.location.to_s.strip if primary && date_in_leg?(date, primary)
    end

    trip.trip_location.to_s.strip
  end

  def self.date_in_leg?(date, leg)
    start_d = Date.parse(leg.start_date.to_s)
    end_d = Date.parse(leg.end_date.to_s)
    date >= start_d && date <= end_d
  rescue Date::Error, TypeError
    false
  end

  # Google-style strings often include admin areas between city and country — keep first and last segments.
  def self.parse_city_country(location)
    parts = location.to_s.split(",").map(&:strip).reject(&:blank?)
    return nil if parts.empty?
    return { city: parts.first, country: parts.first } if parts.length == 1
    return { city: parts.first, country: parts.last } if parts.length == 2

    { city: parts.first, country: parts.last }
  end

  private_class_method :locations_for, :combine_locations, :parse_city_country, :destination_for_plan, :date_in_leg?
end

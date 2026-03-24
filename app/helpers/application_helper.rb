module ApplicationHelper
  # Agenda "Time" column: start time only + zone abbreviation (e.g. "08:00 AM EST").
  # Clock uses IANA zone from Google (place_time_zone_id) when present; else Rails Time.zone.
  # Label prefers AI-stored trip_plan.timezone when set, else Ruby's %Z for that instant.
  def agenda_start_time_with_zone(trip_plan)
    return "" if trip_plan.start_time.blank? || trip_plan.date.blank?

    st = trip_plan.start_time
    d = trip_plan.date
    tz = Time.find_zone(trip_plan.place_time_zone_id) if trip_plan.place_time_zone_id.present?
    tz ||= Time.zone

    time_part, computed_zone =
      if tz.present?
        local = tz.local(d.year, d.month, d.day, st.hour, st.min, st.sec)
        [local.strftime("%I:%M %p"), local.strftime("%Z").to_s.strip]
      else
        [st.strftime("%I:%M %p"), nil]
      end

    zone_label = trip_plan.timezone.to_s.strip.presence || computed_zone
    zone_label.present? ? "#{time_part} #{zone_label}" : time_part
  end

  # Short month + day (no year) for agenda day tabs — e.g. "Sept. 29"
  def agenda_brief_date(date)
    month = case date.month
            when 1 then "Jan."
            when 2 then "Feb."
            when 3 then "Mar."
            when 4 then "Apr."
            when 5 then "May"
            when 6 then "June"
            when 7 then "July"
            when 8 then "Aug."
            when 9 then "Sept."
            when 10 then "Oct."
            when 11 then "Nov."
            when 12 then "Dec."
            end
    "#{month} #{date.day}"
  end
end

module ApplicationHelper
  include Pagy::Frontend
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

  def showcase_hero_image(trip)
    return unless trip.showcase_slug.present?

    ShowcaseImages.hero_asset_name(trip.showcase_slug)
  end

  def showcase_plan_image(trip, trip_plan)
    return unless trip.showcase_slug.present?

    index = ShowcaseImages.plan_index_for(trip, trip_plan)
    ShowcaseImages.plan_asset_name(trip.showcase_slug, index) if index
  end

  def plan_photo_url(trip, trip_plan)
    if (showcase = showcase_plan_image(trip, trip_plan))
      return absolute_asset_url(image_url(showcase))
    end

    return absolute_asset_url(rails_blob_url(trip_plan.place_thumbnail)) if trip_plan.place_thumbnail.attached?

    nil
  end

  def absolute_asset_url(url)
    return if url.blank?
    return url if url.match?(/\Ahttps?:\/\//i)

    "#{request.base_url}#{url.start_with?('/') ? '' : '/'}#{url}"
  end

  def trip_date_range_label(trip)
    return unless trip.trip_start_date.present?

    start_label = trip_display_date(trip.trip_start_date)
    end_date = trip.trip_end_date
    return start_label unless end_date

    end_label = trip_display_date(end_date)
    "From #{start_label} - #{end_label}"
  end

  def trip_display_date(date)
    "#{agenda_brief_date(date)}, #{date.year}"
  end

  def trips_tab_page_url(page_param, page)
    root_path({ page_param => page })
  end
end

module ApplicationHelper
  include Pagy::Frontend

  def mobile_browser?
    request.user_agent.to_s.match?(/Android|iPhone|iPad|iPod/i)
  end

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

  def trip_hero_default_path
    image_path("trip_hero_default.jpg")
  end

  def trip_hero_default_url
    absolute_asset_url(image_path("trip_hero_default.jpg"))
  end

  # Primary src for trip show hero: showcase asset, Google Places photo, or default PNG.
  def trip_show_hero_src(trip)
    if (showcase = showcase_hero_image(trip))
      absolute_asset_url(image_path(showcase))
    elsif trip.location_hero.attached? && active_storage_file_available?(trip.location_hero)
      absolute_asset_url(rails_blob_url(trip.location_hero))
    else
      trip_hero_default_url
    end
  end

  # Fallback chain when hero src fails (missing blob on disk, etc.).
  def trip_hero_image_onerror(fallback_url = trip_hero_default_url)
    safe_fallback = fallback_url.to_s.gsub("'", "\\'")
    "this.onerror=null;this.src='#{safe_fallback}';" \
      "this.onerror=function(){this.classList.add('trip-hero-image--placeholder');this.removeAttribute('src');};"
  end

  def showcase_plan_image(trip, trip_plan)
    return unless trip.showcase_slug.present?

    index = ShowcaseImages.plan_index_for(trip, trip_plan)
    ShowcaseImages.plan_asset_name(trip.showcase_slug, index) if index
  end

  def plan_photo_url(trip, trip_plan)
    if (showcase = showcase_plan_image(trip, trip_plan))
      return absolute_asset_url(image_path(showcase))
    end

    return absolute_asset_url(rails_blob_url(trip_plan.place_thumbnail)) if
      trip_plan.place_thumbnail.attached? && active_storage_file_available?(trip_plan.place_thumbnail)

    nil
  end

  def absolute_asset_url(url)
    return if url.blank?
    return url if url.match?(/\Ahttps?:\/\//i)

    "#{request.base_url}#{url.start_with?('/') ? '' : '/'}#{url}"
  end

  def trip_locations_label(trip)
    TripLocationDisplay.label_for(trip)
  end

  def trip_date_range_label(trip)
    return unless trip.trip_start_date.present?

    start_label = trip_display_date(trip.trip_start_date)
    end_date = trip.trip_end_date
    return start_label unless end_date
    return start_label if end_date == trip.trip_start_date

    end_label = trip_display_date(end_date)
    "#{start_label} - #{end_label}"
  end

  def trip_display_date(date)
    "#{agenda_brief_date(date)}, #{date.year}"
  end

  def trips_tab_page_url(page_param, page)
    root_path({ page_param => page })
  end

  # Full-window navigation — required inside Envoy / mobile WebViews (avoids document.txt downloads).
  def app_link_to(name = nil, url = nil, **html_options, &block)
    top_nav_link_to(name, url, **html_options, &block)
  end

  def top_nav_link_to(name = nil, url = nil, **html_options, &block)
    opts = nav_link_html_options(html_options)
    if block
      link_to(name, opts, &block)
    else
      link_to(name, url, opts)
    end
  end

  def nav_link_html_options(html_options)
    html_options[:data] = (html_options[:data] || {}).merge(turbo: false)
    html_options[:target] = "_top"
    html_options[:rel] = [html_options[:rel], "noopener"].compact.join(" ").presence || "noopener"
    html_options
  end

  def user_avatar_tag(user, **options)
    classes = [options[:class], "user-avatar"].compact.join(" ")
    alt = user.display_name.presence || "Profile"
    html_options = options.except(:class)

    image_tag(
      user_avatar_src(user),
      **html_options.merge(class: classes, alt: alt, onerror: user_avatar_onerror)
    )
  end

  def user_avatar_default_path
    image_path("default_avatar.svg")
  end

  def user_avatar_src(user)
    if user.avatar.attached? && active_storage_file_available?(user.avatar)
      blob = user.avatar.blob
      absolute_asset_url(url_for(user.avatar)) + "?v=#{blob.id}"
    else
      user_avatar_default_path
    end
  end

  def user_avatar_onerror
    safe_fallback = user_avatar_default_path.to_s.gsub("'", "\\'")
    "this.onerror=null;this.src='#{safe_fallback}';"
  end

  def generation_quota_exhausted?
    user_signed_in? && !current_user.premium? && !current_user.can_generate_trip?
  end

  def generation_limit_auto_open?
    return false unless generation_quota_exhausted?

    path = request.path
    path == "/" || path == "/trips" || path.start_with?("/modify/")
  end

  def web_back_link(label = "← Back")
    link_to label, root_path, class: "web-back-link", data: { turbo: false }
  end

  def nalu_contact_mailto
    "mailto:phoebezhu1611@gmail.com?subject=#{ERB::Util.url_encode("Nalu — more trip generations")}"
  end

  # DB may say attached after a deploy when the disk file was wiped (Render local storage).
  def active_storage_file_available?(attachment)
    return false unless attachment.attached?

    attachment.blob.service.exist?(attachment.blob.key)
  rescue StandardError => e
    Rails.logger.warn("[ActiveStorage] blob check failed: #{e.class} #{e.message}")
    false
  end
end

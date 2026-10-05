module ApplicationHelper
  include Pagy::Frontend

  def mobile_browser?
    request.user_agent.to_s.match?(/Android|iPhone|iPad|iPod/i)
  end

  # Agenda "Time" column: local wall clock at the destination (AI times are local, not UTC).
  # Uses Google IANA zone (place_time_zone_id) when set; otherwise shows time without a UTC label.
  def agenda_start_time_with_zone(trip_plan)
    return "" if trip_plan.start_time.blank? || trip_plan.date.blank?

    st = trip_plan.start_time
    d = trip_plan.date
    hour, min, sec = st.hour, st.min, st.sec
    tz = Time.find_zone(trip_plan.place_time_zone_id) if trip_plan.place_time_zone_id.present?

    if tz.present?
      local = tz.local(d.year, d.month, d.day, hour, min, sec)
      time_part = local.strftime("%I:%M %p")
      zone_label = trip_plan.timezone.to_s.strip.presence || local.strftime("%Z").to_s.strip
      zone_label.present? ? "#{time_part} #{zone_label}" : time_part
    else
      Time.utc(2000, 1, 1, hour, min, sec).strftime("%I:%M %p")
    end
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

  HOME_TAB_HERO_FILES = %w[
    home_tab_hero.jpg
    home_tab_hero_02.jpg
    home_tab_hero_03.png
    home_tab_hero_04.png
    home_tab_hero_05.jpg
    home_tab_hero_06.jpg
    home_tab_hero_07.png
    home_tab_hero_08.png
    home_tab_hero_09.jpg
    home_tab_hero_10.jpg
    home_tab_hero_11.png
    home_tab_hero_12.jpg
    home_tab_hero_13.jpg
    home_tab_hero_14.jpg
    home_tab_hero_15.png
    home_tab_hero_16.jpg
    home_tab_hero_17.jpg
    home_tab_hero_18.png
    home_tab_hero_19.jpg
    home_tab_hero_20.png
    home_tab_hero_21.png
    home_tab_hero_22.png
    home_tab_hero_23.jpg
    home_tab_hero_24.jpg
    home_tab_hero_25.jpg
    home_tab_hero_26.jpg
    home_tab_hero_27.jpg
  ].freeze

  def home_tab_hero_src
    image_path(HOME_TAB_HERO_FILES.sample)
  end

  def trip_hero_default_url
    absolute_asset_url(image_path("trip_hero_default.jpg"))
  end

  # Primary src for trip show hero: showcase asset, Google Places photo, or default PNG.
  def trip_show_hero_src(trip)
    if (showcase = showcase_hero_image(trip))
      absolute_asset_url(image_path(showcase))
    elsif trip.location_hero_available?
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

  def saved_spot_thumb_src(trip, trip_plan)
    plan_photo_url(trip, trip_plan) || trip_show_hero_src(trip)
  end

  def saved_spot_thumb_onerror
    trip_hero_image_onerror
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

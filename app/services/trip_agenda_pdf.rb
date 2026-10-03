# frozen_string_literal: true

require "stringio"

require "prawn"
require "prawn/table"

# Builds a multi-page PDF: one page per calendar day of the trip, agenda table per day.
# Trip hero + title block matches the web show page; Location column uses thumbnail + Maps link.
class TripAgendaPdf
  include ApplicationHelper
  include ActionView::Helpers::NumberHelper

  WATERMARK = "Nalu.AI, nahloo.com"
  LOCATION_THUMB = 54
  # Hero frame in PDF points (≈ CSS px at 72dpi). Scales down if narrower than content width.
  HERO_TARGET_WIDTH = 700
  HERO_TARGET_HEIGHT = 200

  def initialize(trip)
    @trip = trip
  end

  def render
    Prawn::Document.new(page_size: "LETTER", margin: [48, 48, 56, 48]) do |pdf|
      dates = agenda_dates
      if dates.empty?
        render_trip_hero_image(pdf)
        draw_watermark_background(pdf)
        draw_watermark_corners(pdf)
        render_trip_title_block(pdf)
        pdf.move_down 12
        pdf.text pdf_plain("This trip has no scheduled days to export."), style: :italic
      else
        dates.each_with_index do |date, idx|
          pdf.start_new_page if idx.positive?
          render_day_page(pdf, date, idx + 1, first_day: idx.zero?)
        end
      end
    end.render
  end

  private

  def agenda_dates
    start_d = @trip.trip_start_date
    return [] if start_d.blank?

    days = @trip.trip_duration_days.to_i
    return [] if days < 1

    end_d = start_d + days.days - 1.day
    (start_d..end_d).to_a
  end

  def draw_watermark_background(pdf)
    pdf.canvas do
      pdf.save_graphics_state do
        pdf.transparent(0.1) do
          pdf.fill_color "9CA3AF"
          pdf.font_size(44) do
            cx = pdf.bounds.left + pdf.bounds.width / 2
            cy = pdf.bounds.bottom + pdf.bounds.height / 2
            twm = pdf_plain(WATERMARK)
            pdf.rotate(32, origin: [cx, cy]) do
              pdf.text_box twm,
                at: [cx - 200, cy - 6],
                width: 400,
                align: :center,
                style: :bold
            end
          end
        end
      end
    end
    pdf.fill_color "000000"
  end

  def draw_watermark_corners(pdf)
    pdf.save_graphics_state do
      pdf.fill_color "BBBBBB"
      pdf.font_size(16) do
        wm = pdf_plain(WATERMARK)
        pdf.draw_text wm, at: [pdf.bounds.left, pdf.bounds.top - 14]
        tw = pdf.width_of(wm)
        pdf.draw_text wm, at: [pdf.bounds.right - tw, pdf.bounds.bottom + 22]
      end
    end
    pdf.fill_color "000000"
  end

  # Fixed 700×200 (pt) hero, left-aligned; scales down proportionally if the margin box is narrower than 700pt.
  # Drawn before watermark canvas() so transparency state cannot affect the image.
  def render_trip_hero_image(pdf)
    data = normalized_hero_bytes
    return if data.blank?

    max_w = pdf.bounds.width
    scale = [1.0, max_w / HERO_TARGET_WIDTH.to_f].min
    box_w = HERO_TARGET_WIDTH * scale
    box_h = HERO_TARGET_HEIGHT * scale

    pdf.bounding_box([pdf.bounds.left, pdf.cursor], width: box_w, height: box_h) do
      io = StringIO.new(data)
      io.rewind
      pdf.image io,
        fit: [box_w, box_h],
        position: :left,
        vposition: :center
    end
    pdf.move_down 10
  rescue StandardError => e
    Rails.logger.warn("TripAgendaPdf hero image skipped: #{e.class} #{e.message}")
  end

  def render_trip_title_block(pdf)
    pdf.font_size(20) do
      pdf.text pdf_plain(@trip.trip_name.to_s.presence || "Trip"), style: :bold
    end
    pdf.move_down 4
    pdf.font_size(11) do
      pdf.text pdf_plain(trip_locations_label(@trip)), color: "525252"
      pdf.move_down 2
      pdf.text pdf_plain(trip_date_range_label(@trip)), color: "525252"
    end
    pdf.move_down 14
    pdf.font_size(15) do
      pdf.text pdf_plain("My Agenda"), style: :bold, color: "0F172A"
    end
    pdf.move_down 8
  end

  def default_hero_bytes
    path = Rails.root.join("app/assets/images/trip_hero_default.jpg")
    return "".b unless path.file?

    File.binread(path)
  end

  def trip_hero_bytes_raw
    if (static = ShowcaseImages.hero_bytes(@trip.showcase_slug))
      return static
    end

    if @trip.location_hero.attached?
      @trip.location_hero.download
    else
      default_hero_bytes
    end
  rescue StandardError => e
    Rails.logger.warn("TripAgendaPdf hero download: #{e.class} #{e.message}")
    default_hero_bytes
  end

  # Prawn only embeds JPEG/PNG reliably; Google Place photos may be WebP.
  def prawn_supported_raster?(data)
    return false if data.blank?

    return false if data.bytesize >= 12 && data[0, 4] == "RIFF" && data[8, 4] == "WEBP"

    data.start_with?("\xFF\xD8".b) || data.start_with?("\x89PNG".b)
  end

  def normalized_hero_bytes
    raw = trip_hero_bytes_raw
    return default_hero_bytes if raw.blank?
    return default_hero_bytes unless prawn_supported_raster?(raw)

    raw
  end

  def render_day_page(pdf, date, day_number, first_day: false)
    if first_day
      render_trip_hero_image(pdf)
    end
    draw_watermark_background(pdf)
    draw_watermark_corners(pdf)
    if first_day
      render_trip_title_block(pdf)
    end

    pdf.font_size(13) do
      pdf.text pdf_plain(
        "Day #{day_number} — #{agenda_brief_date(date)} (#{date.strftime('%A, %B %-d, %Y')})"
      ),
               style: :bold,
               color: "0F172A"
    end
    pdf.move_down 12

    col_w = column_widths(pdf.bounds.width)
    rows = build_table_rows(pdf, date, col_w[2])
    w = pdf.bounds.width

    pdf.font_size(9) do
      pdf.table(rows, header: true, column_widths: col_w, width: w) do |t|
        t.cells.borders = %i[top bottom left right]
        t.cells.border_width = 0.5
        t.cells.border_color = "CCCCCC"
        t.cells.padding = [5, 6]
        t.row(0).background_color = "F1F5F9"
        t.row(0).text_color = "374151"
        t.row(0).font_style = :bold
      end
    end
  end

  def column_widths(total_w)
    [
      total_w * 0.12,
      total_w * 0.26,
      total_w * 0.32,
      total_w * 0.30
    ]
  end

  def build_table_rows(pdf, date, location_col_w)
    header = ["Time", "Plan", "Location", "Get around"]
    plans = @trip.trip_plans.where(date: date).order(:start_time).to_a

    if plans.empty?
      return [
        header.map { |h| pdf_plain(h) },
        [{ content: pdf_plain("No activities scheduled for this day."), colspan: 4, align: :center, font_style: :italic }]
      ]
    end

    inner_loc_w = [location_col_w - 12, LOCATION_THUMB + 8].max

    [header.map { |h| pdf_plain(h) }] + plans.map do |plan|
      [
        pdf_plain(agenda_start_time_with_zone(plan)),
        plan_column_cell(plan),
        location_subtable(pdf, plan, inner_loc_w),
        pdf_plain((plan.plan_details.presence || "—").to_s.truncate(400))
      ]
    end
  end

  def location_subtable(pdf, plan, width)
    rows = []
    thumb_data = nil
    if @trip.showcase_slug.present?
      index = ShowcaseImages.plan_index_for(@trip, plan)
      thumb_data = ShowcaseImages.plan_bytes(@trip.showcase_slug, index) if index
    end
    if thumb_data.blank? && plan.place_thumbnail.attached?
      begin
        thumb_data = plan.place_thumbnail.download
      rescue StandardError => e
        Rails.logger.warn("TripAgendaPdf place thumbnail skipped: #{e.class} #{e.message}")
      end
    end
    if thumb_data.present?
      begin
        if prawn_supported_raster?(thumb_data)
          io = StringIO.new(thumb_data)
          io.rewind
          # Fixed square (stretch to fill), same visual box for every row.
          rows << [{
            image: io,
            image_width: LOCATION_THUMB,
            image_height: LOCATION_THUMB,
            position: :left,
            vposition: :center,
            padding: [0, 0, 6, 0]
          }]
        end
      rescue StandardError => e
        Rails.logger.warn("TripAgendaPdf place thumbnail skipped: #{e.class} #{e.message}")
      end
    end

    href = plan.google_maps_search_url
    display = plan.place_display_name.presence || plan.plan_location.to_s.split(",").first.to_s
    display = display.presence || "—"
    link_cell =
      if href.present?
        {
          content: maps_link_markup(href, xml_escape_for_link(display)),
          inline_format: true,
          text_color: "1D4ED8",
          size: 9,
          padding: [0, 0, 4, 0]
        }
      else
        { content: pdf_plain(display), size: 9, padding: [0, 0, 4, 0] }
      end
    rows << [link_cell]

    if plan.place_rating.present?
      cnt = plan.place_user_ratings_total.to_i
      rating_txt = pdf_plain("#{number_with_precision(plan.place_rating, precision: 1)} * (#{cnt})")
      rows << [{ content: rating_txt, size: 8, text_color: "4B5563", padding: 0 }]
    end

    pdf.make_table(rows, width: width, cell_style: { borders: [], border_width: 0 })
  end

  # Prawn copies href into the PDF URI without decoding XML entities — do NOT use &amp; or the link breaks.
  def maps_link_markup(url, label_xml_inner)
    href = url.to_s.gsub('"', "%22")
    "<link href=\"#{href}\">#{label_xml_inner}</link>"
  end

  def xml_escape_for_link(str)
    pdf_plain(str).gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub("\"", "&quot;")
  end

  def xml_escape_for_inline(str)
    str.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end

  def plan_column_cell(plan)
    brief = plan.plan_brief.to_s.strip.presence
    detail = plan.trip_plan.to_s.strip.presence
    return pdf_plain("—") if brief.blank? && detail.blank?

    parts = []
    parts << "<b>#{xml_escape_for_inline(pdf_plain(brief))}</b>" if brief.present?
    if detail.present?
      body = xml_escape_for_inline(pdf_plain(detail))
      parts << (parts.any? ? "\n\n#{body}" : body)
    end
    { content: parts.join, inline_format: true }
  end

  # Prawn Helvetica only encodes Windows-1252; replace anything else so export never fails on emoji/Arabic/etc.
  def pdf_plain(str)
    str.to_s.encode(Encoding::Windows_1252, invalid: :replace, undef: :replace, replace: "?")
  end
end

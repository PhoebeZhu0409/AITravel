# frozen_string_literal: true

# Public marketing / legal pages (no login required).
class PagesController < ApplicationController
  skip_before_action :authenticate_user!

  # Hard-coded demo trips for /showcase/* (must match DB records).
  SHOWCASE_TRIP_IDS = { madrid: 10, new_york: 4 }.freeze
  ALLOWED_PUBLIC_SHOWCASE_TRIP_IDS = SHOWCASE_TRIP_IDS.values.freeze

  def legal_notices
   render({ :template => "trip_templates/legal_notices" })
  end

  def terms_of_use
    render({ :template => "trip_templates/terms_of_use" })
  end
  
  def privacy_policy
    render({ :template => "trip_templates/privacy_policy" })
  end

  def showcase_madrid
    render_showcase_trip(SHOWCASE_TRIP_IDS[:madrid], showcase_madrid_pdf_path)
  end

  def showcase_new_york
    render_showcase_trip(SHOWCASE_TRIP_IDS[:new_york], showcase_new_york_pdf_path)
  end

  def showcase_madrid_pdf
    deliver_showcase_pdf(SHOWCASE_TRIP_IDS[:madrid])
  end

  def showcase_new_york_pdf
    deliver_showcase_pdf(SHOWCASE_TRIP_IDS[:new_york])
  end

  private

  def render_showcase_trip(trip_id, agenda_pdf_path)
    unless ALLOWED_PUBLIC_SHOWCASE_TRIP_IDS.include?(trip_id)
      head :not_found
      return
    end

    @the_trip = Trip.find_by(id: trip_id)
    unless @the_trip
      head :not_found
      return
    end

    @trip_show_public_demo = true
    @showcase_agenda_pdf_path = agenda_pdf_path
    @trip_show_page_title = "#{@the_trip.trip_name} · Nalu"
    render({ :template => "trip_templates/show" })
  end

  def deliver_showcase_pdf(trip_id)
    unless ALLOWED_PUBLIC_SHOWCASE_TRIP_IDS.include?(trip_id)
      head :not_found
      return
    end

    trip = Trip.find_by(id: trip_id)
    unless trip
      head :not_found
      return
    end

    pdf_bytes = ::TripAgendaPdf.new(trip).render
    base = trip.trip_name.to_s.parameterize.presence || "trip"
    filename = "#{base}-agenda.pdf"
    headers["Content-Disposition"] = ActionDispatch::Http::ContentDisposition.format(
      disposition: "attachment",
      filename: filename
    )
    send_data pdf_bytes, type: "application/pdf", disposition: nil
  rescue StandardError => e
    Rails.logger.error("showcase agenda PDF failed for trip #{trip_id}: #{e.class} #{e.message}\n#{e.backtrace&.first(15)&.join("\n")}")
    head :internal_server_error
  end
end

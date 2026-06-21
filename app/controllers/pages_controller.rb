# frozen_string_literal: true

# Public marketing / legal pages (no login required).
class PagesController < ApplicationController
  skip_before_action :authenticate_user!

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
    render_showcase_trip("madrid", showcase_madrid_pdf_path)
  end

  def showcase_new_york
    render_showcase_trip("new_york", showcase_new_york_pdf_path)
  end

  def showcase_madrid_pdf
    deliver_showcase_pdf("madrid")
  end

  def showcase_new_york_pdf
    deliver_showcase_pdf("new_york")
  end

  private

  def render_showcase_trip(slug, agenda_pdf_path)
    unless Trip::SHOWCASE_SLUGS.include?(slug)
      head :not_found
      return
    end

    @the_trip = Trip.find_by(showcase_slug: slug)
    unless @the_trip
      head :not_found
      return
    end

    @trip_show_public_demo = true
    @showcase_agenda_pdf_path = agenda_pdf_path
    @trip_show_page_title = "#{@the_trip.trip_name} · Nalu"
    render({ :template => "trip_templates/show" })
  end

  def deliver_showcase_pdf(slug)
    unless Trip::SHOWCASE_SLUGS.include?(slug)
      head :not_found
      return
    end

    trip = Trip.find_by(showcase_slug: slug)
    unless trip
      head :not_found
      return
    end

    pdf_bytes = ::TripAgendaPdf.new(trip).render
    base = trip.trip_name.to_s.parameterize.presence || "trip"
    filename = "#{base}-agenda.pdf"
    headers["Cache-Control"] = "no-store, private"
    headers["Content-Disposition"] = ActionDispatch::Http::ContentDisposition.format(
      disposition: "attachment",
      filename: filename
    )
    send_data pdf_bytes, type: "application/pdf", disposition: nil
  rescue StandardError => e
    Rails.logger.error("showcase agenda PDF failed for slug #{slug}: #{e.class} #{e.message}\n#{e.backtrace&.first(15)&.join("\n")}")
    head :internal_server_error
  end
end

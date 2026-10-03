class TripsController < ApplicationController
  before_action :set_owned_trip, only: %i[show generation_status trip_name_update rebuild_form destroy update agenda_pdf]

  def index
    matching_trips = current_user.trips

    future_scope = matching_trips
      .where(trip_start_date: (Date.today...))
      .order(created_at: :desc)
    past_scope = matching_trips
      .where(trip_start_date: (...Date.today))
      .order(created_at: :desc)

    @pagy_future, @future_trips = pagy(future_scope, page_param: :future_page, limit: 10)
    @pagy_past, @past_trips = pagy(past_scope, page_param: :past_page, limit: 10)
    @trip_form = (session.delete(:trip_form_draft) || {}).stringify_keys

    render({ :template => "trip_templates/index" })
  end

  def plan_a_day
    render({ :template => "trip_templates/plan_a_day" })
  end


  def show
    unless @trip_show_public_demo
      ::TripGenerationEnqueuer.retry_if_needed!(@the_trip)
    end

    @agenda_generating = !@trip_show_public_demo && @the_trip.trip_plans.none?

    render({ :template => "trip_templates/show" })
  end

  def generation_status
    render json: { ready: @the_trip.trip_plans.any?, count: @the_trip.trip_plans.count }
  end

  def agenda_pdf
    pdf_bytes = ::TripAgendaPdf.new(@the_trip).render
    base = @the_trip.trip_name.to_s.parameterize.presence || "trip"
    filename = "#{base}-agenda.pdf"
    headers["Cache-Control"] = "no-store, private"
    headers["Content-Disposition"] = ActionDispatch::Http::ContentDisposition.format(
      disposition: "attachment",
      filename: filename
    )
    send_data pdf_bytes, type: "application/pdf", disposition: nil
  rescue StandardError => e
    Rails.logger.error("agenda_pdf failed for trip #{@the_trip&.id}: #{e.class} #{e.message}\n#{e.backtrace&.first(15)&.join("\n")}")
    redirect_to("/trips/#{@the_trip.id}", alert: "Could not generate the PDF. Please try again.")
  end

  def trip_name_update
    @the_trip.trip_name = params.fetch("query_trip_name")
    if @the_trip.save
      redirect_to "/trips/#{@the_trip.id}", notice: "Trip name updated."
    else
      redirect_to "/trips/#{@the_trip.id}", alert: @the_trip.errors.full_messages.to_sentence
    end
  end

  def rebuild_form
    unless current_user.can_generate_trip?
      redirect_to("/trips/#{@the_trip.id}", { alert: trip_generation_limit_message })
      return
    end

    @rebuild_prefill = ::RebuildFormPrefill.from_trip_notes(@the_trip.trip_notes)
    render({ :template => "trip_templates/edit_trip" })
  end

  def destroy
    @the_trip.destroy
    redirect_to("/trips", { :notice => "Trip deleted successfully." })
  end

  # =============================== Update =================================
  def update
    unless current_user.can_generate_trip?
      redirect_to("/trips/#{@the_trip.id}", { alert: trip_generation_limit_message })
      return
    end

    @the_trip.trip_name = params.fetch("query_trip_name")
    @the_trip.trip_location = params.fetch("query_trip_location")
    apply_trip_date_range!(@the_trip)
    @the_trip.trip_notes = build_trip_summary

    if @the_trip.valid?
      @the_trip.trip_plans.destroy_all
      @the_trip.save
      ::TripGenerationEnqueuer.call(@the_trip.id)

      redirect_to(
        "/trips/#{@the_trip.id}",
        notice: "Your agenda is being generated. This page will refresh automatically.",
        status: :see_other
      )
    else
      redirect_to("/trips/#{@the_trip.id}", { alert: @the_trip.errors.full_messages.to_sentence })
    end
  end

  # =============================== Create =================================
  def create
    unless current_user.can_generate_trip?
      session[:trip_form_draft] = trip_form_draft_params.to_h
      redirect_to("/trips", { alert: trip_generation_limit_message })
      return
    end

    the_trip = Trip.new
    the_trip.user_id = current_user.id
    the_trip.trip_name = params.fetch("query_trip_name")
    the_trip.trip_location = params.fetch("query_trip_location")
    apply_trip_date_range!(the_trip)
    the_trip.trip_notes = build_trip_summary

    if the_trip.valid?
      the_trip.save
      ::TripGenerationEnqueuer.call(the_trip.id)

      redirect_to(
        "/trips/#{the_trip.id}",
        notice: "Your agenda is being generated. This page will refresh automatically.",
        status: :see_other
      )
    else
      session[:trip_form_draft] = trip_form_draft_params.to_h
      redirect_to("/trips", { alert: the_trip.errors.full_messages.to_sentence })
    end
  end

  private

  def trip_generation_limit_message
    "Regular accounts can generate or rebuild up to #{User::REGULAR_GENERATION_LIMIT} trips every " \
      "6 months. You have reached that limit. Contact support or upgrade to premium for unlimited generations."
  end

  def set_owned_trip
    @the_trip = current_user.trips
      .with_attached_location_hero
      .includes(trip_plans: :place_thumbnail_attachment)
      .find_by(id: params.fetch("path_id"))
    return if @the_trip

    redirect_to("/trips", alert: "Trip not found.")
  end

  def build_trip_summary
    query_budget = params[:query_budget]
    summary_a = "Budget wise, I want my trip to be #{query_budget}" if query_budget.present?

    query_people = params[:query_people]
    summary_b = "I am #{query_people}" if query_people.present?

    query_todo = params[:query_todo]
    todo_text = query_todo.is_a?(Array) ? query_todo.join(", ") : query_todo
    summary_c = "My trip should include a mix of these: #{todo_text}" if todo_text.present?

    trip_notes = params[:query_trip_notes]
    summary_e = "Specifically, I have these requirements: #{trip_notes}" if trip_notes.present?

    [summary_a, summary_b, summary_c, summary_e].compact.join(" ; ")
  end

  def apply_trip_date_range!(trip)
    start_date = Date.parse(params.fetch("query_trip_start_date"))
    end_date = Date.parse(params.fetch("query_trip_end_date"))

    if end_date < start_date
      trip.errors.add(:base, "Trip end must be on or after trip start.")
      return
    end

    trip.trip_start_date = start_date
    duration_days = (end_date - start_date).to_i + 1

    if duration_days > Trip::MAX_TRIP_DURATION_DAYS
      trip.errors.add(:trip_duration_days, "We can't build trips longer than #{Trip::MAX_TRIP_DURATION_DAYS} days")
      return
    end

    trip.trip_duration_days = duration_days
  rescue Date::Error, TypeError
    trip.errors.add(:base, "Please enter valid trip start and end dates.")
  end

  def trip_form_draft_params
    params.permit(
      :query_trip_name,
      :query_trip_location,
      :query_trip_start_date,
      :query_trip_end_date,
      :query_budget,
      :query_people,
      :query_trip_notes,
      query_todo: []
    )
  end
end

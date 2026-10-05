class TripsController < ApplicationController
  before_action :set_owned_trip, only: %i[show generation_status trip_name_update rebuild_form destroy update agenda_pdf]


  #====================   Plan A Trip: Plan Page, Future Trips, Past Trips ================= 
  def index
    matching_trips = current_user.trips.with_attached_location_hero

    future_scope = matching_trips
      .where(trip_start_date: (Date.today...))
      .order(created_at: :desc)

    past_scope = matching_trips
      .where(trip_start_date: (...Date.today))
      .order(created_at: :desc)

    @pagy_future, @future_trips = pagy(future_scope, page_param: :future_page, limit: 10)
    @pagy_past, @past_trips = pagy(past_scope, page_param: :past_page, limit: 10)

    saved_scope = current_user.saved_trip_plans
      .includes(trip_plan: [:trip, { place_thumbnail_attachment: :blob }])
      .order(created_at: :desc)
    @pagy_saved, @saved_spots = pagy(saved_scope, page_param: :saved_page, limit: 10)
    enqueue_missing_saved_spot_thumbnails(@saved_spots)
    enqueue_missing_trip_location_heroes(@future_trips.to_a + @past_trips.to_a)
    @trip_form = (session.delete(:trip_form_draft) || {}).stringify_keys

    render({ :template => "trip_templates/index" })
  end

    #===============================  Show Trip  =============================== 

  def show
    unless @trip_show_public_demo
      ::TripGenerationEnqueuer.retry_if_needed!(@the_trip)
    end

    @agenda_generating = !@trip_show_public_demo && @the_trip.trip_plans.none?

    unless @trip_show_public_demo
      GooglePlacesEnricher.ensure_trip_destination_time_zones!(@the_trip)
      @saved_trip_plan_ids = current_user.saved_trip_plans.pluck(:trip_plan_id).to_set
    end

    render({ :template => "trip_templates/show" })
  end

   #===================================================================================
  def generation_status
    render json: { ready: @the_trip.trip_plans.any?, count: @the_trip.trip_plans.count }
  end

  def agenda_pdf
    pdf_bytes = ::TripAgendaPdf.new(@the_trip).render
    base = @the_trip.trip_name.to_s.parameterize.presence || "trip"
    filename = "#{base}-agenda.pdf"
    # iOS WKWebView often fails Content-Disposition: attachment; inline keeps the session and shows the PDF.
    ios = request.user_agent.to_s.match?(/iPhone|iPad|iPod/i)
    headers["Cache-Control"] = "no-store, private"
    headers["Content-Disposition"] = ActionDispatch::Http::ContentDisposition.format(
      disposition: ios ? "inline" : "attachment",
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

    if request.xhr? || request.format.json? || request.headers["Accept"].to_s.include?("application/json")
      render json: { ok: true }
    else
      redirect_to("/", notice: "Trip deleted successfully.", status: :see_other)
    end
  end
   #===================================================================================

  # =============================== Update Trip =================================
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

  def enqueue_missing_saved_spot_thumbnails(saved_spots)
    saved_spots.each do |saved|
      plan = saved.trip_plan
      next unless plan
      next if plan.place_thumbnail_available?

      EnsurePlaceThumbnailJob.perform_later(plan.id)
    end
  end

  def enqueue_missing_trip_location_heroes(trips)
    trips.each do |trip|
      next if trip.showcase_slug.present?
      next if trip.location_hero_available?

      EnsureTripLocationHeroJob.perform_later(trip.id)
    end
  end

  def trip_generation_limit_message
    "Uh oh 🥲 — you’ve used all your free generations (#{User::REGULAR_GENERATION_LIMIT} every 6 months). " \
      "If you’d like to keep planning with Nalu, email Phoebe — tap Contact Phoebe."
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
    parts = []
    parts << primary_leg_note if primary_leg_note.present?
    parts << second_leg_note if second_leg_note.present?

    query_budget = params[:query_budget]
    parts << "Budget wise, I want my trip to be #{query_budget}" if query_budget.present?

    query_people = params[:query_people]
    parts << "I am #{query_people}" if query_people.present?

    query_todo = params[:query_todo]
    todo_text = query_todo.is_a?(Array) ? query_todo.join(", ") : query_todo
    parts << "My trip should include a mix of these: #{todo_text}" if todo_text.present?

    trip_notes = params[:query_trip_notes]
    parts << "Specifically, I have these requirements: #{trip_notes}" if trip_notes.present?

    parts.compact.join(" ; ")
  end

  def apply_trip_date_range!(trip)
    leg1_start, leg1_end = parse_leg_dates("query_trip_start_date", "query_trip_end_date")
    return if leg1_start.nil? || leg1_end.nil?

    if leg1_end < leg1_start
      trip.errors.add(:base, "Trip end must be on or after trip start.")
      return
    end

    leg2_loc = params[:query_trip_location_2].to_s.strip
    leg2_start, leg2_end = parse_leg_dates("query_trip_start_date_2", "query_trip_end_date_2")

    if leg2_loc.present?
      if leg2_start.nil? || leg2_end.nil?
        trip.errors.add(:base, "Please enter start and end dates for the second location.")
        return
      end
      if leg2_end < leg2_start
        trip.errors.add(:base, "Second location end must be on or after its start date.")
        return
      end

      required_leg2_start = leg1_end + 1.day
      if leg2_start != required_leg2_start
        trip.errors.add(
          :base,
          "Second location must start on #{required_leg2_start.iso8601} (the day after the first location ends)."
        )
        return
      end
    elsif params[:query_trip_start_date_2].present? || params[:query_trip_end_date_2].present?
      trip.errors.add(:base, "Please enter a second location or clear its dates.")
      return
    end

    overall_start = leg1_start
    overall_end = leg2_loc.present? ? leg2_end : leg1_end

    trip.trip_start_date = overall_start
    duration_days = (overall_end - overall_start).to_i + 1

    if duration_days > Trip::MAX_TRIP_DURATION_DAYS
      trip.errors.add(:trip_duration_days, "We can't build trips longer than #{Trip::MAX_TRIP_DURATION_DAYS} days")
      return
    end

    trip.trip_duration_days = duration_days
  rescue Date::Error, TypeError
    trip.errors.add(:base, "Please enter valid trip start and end dates.")
  end

  def primary_leg_note
    loc = params[:query_trip_location].to_s.strip
    start_s = params[:query_trip_start_date].to_s.strip
    end_s = params[:query_trip_end_date].to_s.strip
    return if loc.blank? || start_s.blank? || end_s.blank?

    ::TripLegNotes.format_leg(::TripLegNotes::PRIMARY_PREFIX, loc, start_s, end_s)
  end

  def second_leg_note
    loc = params[:query_trip_location_2].to_s.strip
    start_s = params[:query_trip_start_date_2].to_s.strip
    end_s = params[:query_trip_end_date_2].to_s.strip
    return if loc.blank?

    ::TripLegNotes.format_leg(::TripLegNotes::SECOND_PREFIX, loc, start_s, end_s)
  end

  def parse_leg_dates(start_param, end_param)
    start_date = Date.parse(params.fetch(start_param))
    end_date = Date.parse(params.fetch(end_param))
    [start_date, end_date]
  rescue Date::Error, TypeError, KeyError
    [nil, nil]
  end

  def trip_form_draft_params
    params.permit(
      :query_trip_name,
      :query_trip_location,
      :query_trip_start_date,
      :query_trip_end_date,
      :query_trip_location_2,
      :query_trip_start_date_2,
      :query_trip_end_date_2,
      :query_budget,
      :query_people,
      :query_trip_notes,
      query_todo: []
    )
  end
end

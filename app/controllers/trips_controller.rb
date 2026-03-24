class TripsController < ApplicationController
  before_action :set_owned_trip, only: %i[show trip_name_update rebuild_form destroy update]

  def index
    matching_trips = current_user.trips
    @list_of_trips = matching_trips.order({ :created_at => :desc })
    @trip_form = (session.delete(:trip_form_draft) || {}).stringify_keys

    render({ :template => "trip_templates/index" })
  end


  def show
    render({ :template => "trip_templates/show" })
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
    @rebuild_prefill = ::RebuildFormPrefill.from_trip_notes(@the_trip.trip_notes)
    render({ :template => "trip_templates/edit_trip" })
  end

  def destroy
    @the_trip.destroy
    redirect_to("/trips", { :notice => "Trip deleted successfully." })
  end

  # =============================== Update =================================
  def update
    @the_trip.trip_name = params.fetch("query_trip_name")
    @the_trip.trip_location = params.fetch("query_trip_location")
    @the_trip.trip_duration_days = params.fetch("query_trip_duration_days")
    @the_trip.trip_start_date = params.fetch("query_trip_start_date")
    @the_trip.trip_notes = build_trip_summary

    if @the_trip.valid?
      @the_trip.save

      begin
        plan_hash = generate_ai_plan_for(@the_trip)
        replace_trip_plans_from_ai!(@the_trip, plan_hash)

        redirect_to("/trips/#{@the_trip.id}", { notice: "Trip updated successfully." })
      rescue JSON::ParserError => e
        Rails.logger.error("Trip #{@the_trip.id} JSON parse failed: #{e.message}")
        redirect_to("/trips/#{@the_trip.id}", { alert: "Trip was updated, but the AI returned invalid JSON." })
      rescue StandardError => e
        Rails.logger.error("Trip #{@the_trip.id} generation failed: #{e.class} - #{e.message}")
        redirect_to("/trips/#{@the_trip.id}", { alert: "Trip was updated, but itinerary generation failed." })
      end
    else
      redirect_to("/trips/#{@the_trip.id}", { alert: @the_trip.errors.full_messages.to_sentence })
    end
  end

  # =============================== Create =================================
  def create
    the_trip = Trip.new
    the_trip.user_id = current_user.id
    the_trip.trip_name = params.fetch("query_trip_name")
    the_trip.trip_location = params.fetch("query_trip_location")
    the_trip.trip_duration_days = params.fetch("query_trip_duration_days")
    the_trip.trip_start_date = params.fetch("query_trip_start_date")
    the_trip.trip_notes = build_trip_summary

    if the_trip.valid?
      the_trip.save

      begin
        plan_hash = generate_ai_plan_for(the_trip)
        replace_trip_plans_from_ai!(the_trip, plan_hash)

        redirect_to("/trips/#{the_trip.id}", { notice: "Trip created successfully." })
      rescue JSON::ParserError => e
        Rails.logger.error("Trip #{the_trip.id} JSON parse failed: #{e.message}")
        redirect_to("/trips/#{the_trip.id}", { alert: "Trip was saved, but the AI returned invalid JSON." })
      rescue StandardError => e
        Rails.logger.error("Trip #{the_trip.id} generation failed: #{e.class} - #{e.message}")
        redirect_to("/trips/#{the_trip.id}", { alert: "Trip was saved, but itinerary generation failed." })
      end
    else
      session[:trip_form_draft] = trip_form_draft_params.to_h
      redirect_to("/trips", { alert: the_trip.errors.full_messages.to_sentence })
    end
  end

  private

  def set_owned_trip
    @the_trip = current_user.trips.find_by(id: params.fetch("path_id"))
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

    live_area = params[:query_live_area]
    summary_d = "I stay near #{live_area}; and I can also go any other places you recommend" if live_area.present?

    trip_notes = params[:query_trip_notes]
    summary_e = "Specifically, I have these requirements: #{trip_notes}" if trip_notes.present?

    [summary_a, summary_b, summary_c, summary_d, summary_e].compact.join(" ; ")
  end

  def generate_ai_plan_for(the_trip)
    user_input = build_user_input(the_trip)

    i = AI::Chat.new
    i.system(ai_planning_prompt)
    i.user(user_input)

    response = i.generate!
    raw = response[:content].to_s

    JSON.parse(raw, symbolize_names: true)
  end

  def build_user_input(the_trip)
    <<~TEXT.squish
      Destination: #{the_trip.trip_location}.
      Start date: #{the_trip.trip_start_date}.
      Duration: #{the_trip.trip_duration_days} days.
      Notes: #{the_trip.trip_notes}
      Produce the itinerary JSON as specified. No prose outside JSON.
    TEXT
  end

  # Single compact system prompt: less input tokens, tighter output (faster / cheaper).
  def ai_planning_prompt
    <<~SYS
      You output ONLY valid JSON (no markdown, no code fences, no commentary).

      Shape:
      {"days":[{"date":"YYYY-MM-DD","items":[{"start_time":"HH:MM","end_time":"HH:MM","activity":"string","plan_brief":"string","location":"string","commute":"string"}]}]}

      Rules:
      - Cover every calendar day from the user's start date through the full trip duration; one object per day in "days".
      - Each day: at most 5 items; choose 4–5 must-do highlights per day (not more).
      - start_time / end_time: local time at destination, 24-hour HH:MM.
      - activity: at most ONE sentence.
      - plan_brief: max 4 words.
      - location: venue or place name + neighborhood or area + city (enough to find on Google Maps; do not invent street numbers).
      - commute: at most ONE short sentence (how to get from the previous stop or hotel). Mention tickets/reservations only if essential before arrival.
      - Omit timezone fields; times are local to the trip destination the user gave.
      - If unknown, assume reasonably; keep text short.
    SYS
  end

  # Replaces trip_plans from parsed AI JSON; enriches each row once via Google Places after commit
  # (HTTP stays out of the DB transaction).
  # "timezone" on each row comes from the user's trip_location (form), not from the LLM.
  def replace_trip_plans_from_ai!(the_trip, plan_hash)
    new_plans = []
    trip_tz_id = ::GooglePlacesEnricher.timezone_id_for_location(
      the_trip.trip_location,
      the_trip.trip_start_date
    )

    ActiveRecord::Base.transaction do
      the_trip.trip_plans.destroy_all

      plan_hash.fetch(:days, []).each do |day|
        date = Date.parse(day[:date])

        day.fetch(:items, []).first(5).each do |item|
          new_plans << TripPlan.create!(
            trip: the_trip,
            date: date,
            start_time: Time.parse(item[:start_time].to_s),
            end_time: Time.parse(item[:end_time].to_s),
            timezone: timezone_abbreviation_for_date(trip_tz_id, date),
            trip_plan: item[:activity],
            plan_brief: item[:plan_brief],
            user_id: the_trip.user_id,
            plan_location: item[:location],
            plan_details: item[:commute]
          )
        end
      end
    end

    new_plans.each { |tp| ::GooglePlacesEnricher.enrich_trip_plan(tp) }
  end

  # Abbreviation (e.g. EST) for a calendar day at the trip destination; handles DST using that date.
  def timezone_abbreviation_for_date(iana_id, date)
    return nil if iana_id.blank? || date.blank?

    tz = Time.find_zone(iana_id)
    return nil unless tz

    tz.local(date.year, date.month, date.day, 12, 0, 0).strftime("%Z").presence
  end

  def trip_form_draft_params
    params.permit(
      :query_trip_name,
      :query_trip_location,
      :query_trip_duration_days,
      :query_trip_start_date,
      :query_budget,
      :query_people,
      :query_live_area,
      :query_trip_notes,
      query_todo: []
    )
  end
end

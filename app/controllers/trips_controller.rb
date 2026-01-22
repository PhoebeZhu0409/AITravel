class TripsController < ApplicationController
  # def ai
  #   require "ai-chat"
  #   require "dotenv/load"
  #   i = AI::Chat.new
  #   i.system("you provide a representative single picture that can be put in <img src=" " > based on user's input of a location")
  #   i.schema = '{"name": "links","strict": true,"schema": {"type": "object","properties": {"link": {"type": "string","description": "The link of the picture based on user input"}},"required": ["link"],"additionalProperties": false}}'

  #   the_id = params.fetch("path_id")
  #   the_trip = Trip.where({ :id => the_id }).at(0)
  #   @location = the_trip.trip_location
  #   @location = @location.gsub(", ", "_")
  #   i.user(@location)
  #   @response = i.generate!
  #   @pic = @response[:content][:link]

  #   render({ :template => "trip_templates/ai_agenda" })
  # end
  

  def index
    matching_trips = current_user.trips
    @list_of_trips = matching_trips.order({ :created_at => :desc })

    render({ :template => "trip_templates/index" })
  end



  def show
    the_id = params.fetch("path_id")
    matching_trips = current_user.trips.where({ :id => the_id })
    @the_trip = matching_trips.at(0)
    # if @the_trip == nil
    #   redirect_to("/", { :alert => "Not found" })
    #   return
    # end
    render({ :template => "trip_templates/show" })
  end


  def trip_name_update
    the_id = params.fetch("path_id")
    the_trip = Trip.where({ :id => the_id }).at(0)
    the_trip.trip_name = params.fetch("query_trip_name")
    the_trip.save
    redirect_to "/trips/#{the_trip.id}"
  end


  def toggle_done
  the_trip = Trip.where({ :id => params.fetch("path_id") }).at(0)
  
  # you must send trip_plan_id "a_day" from the form
  the_trip_plan = TripPlan.where({ :id => params.fetch("a_day") }).at(0)

  new_value = (params.fetch("done") == "true")
  the_trip_plan.update({ :done => new_value })

  redirect_to "/trips/#{the_trip.id}"
  end


  def rebuild_form
    the_id = params.fetch("path_id")
    matching_trips = Trip.where({ :id => the_id })
    @the_trip = matching_trips.at(0)
    render({ :template => "trip_templates/edit_trip" })
  end

  def destroy
    the_id = params.fetch("path_id")
    the_trip = Trip.where({ :id => the_id }).at(0)

    the_trip.destroy

    redirect_to("/trips", { :notice => "Trip deleted successfully." })
  end

  def update
    the_id = params.fetch("path_id")
    the_trip = Trip.where({ :id => the_id }).at(0)

    the_trip.trip_name = params.fetch("query_trip_name")
    the_trip.trip_location = params.fetch("query_trip_location")
    the_trip.trip_duration_days = params.fetch("query_trip_duration_days")
    the_trip.trip_start_date = params.fetch("query_trip_start_date")
    query_budget = params[:query_budget]
    summary_a = "Budget wise, I want my trip to be #{query_budget}" if query_budget.present?

    query_people = params[:query_people]
    summary_b = "I am #{query_people}" if query_people.present?

    query_todo = params[:query_todo]
    summary_c = "My trip should include a mix of these: #{query_todo}" if query_todo.present?

    live_area = params[:query_live_area]
    summary_d = "I stay near #{live_area}; and I can also go any other places you recommend" if live_area.present?

    trip_notes = params[:query_trip_notes]
    summary_e = "Specifically, I have these requirements: #{trip_notes}" if trip_notes.present?

    @summary = [summary_a, summary_b, summary_c, summary_d, summary_e].compact.join(" ; ")

    the_trip.trip_notes = @summary

    # ============================== AI Ouput ===================================
    require "bundler/setup"
    require "ai-chat"
    require "dotenv/load"
    require "json"
    require "time"

    @the_id = the_trip.id
    @trip_location = the_trip.trip_location
    @trip_duration_days = the_trip.trip_duration_days
    @trip_start_date = the_trip.trip_start_date
    @trip_notes = the_trip.trip_notes
    @trip_name = the_trip.trip_name

    @user_input = "I am traveling to " + @trip_location + ", from " + @trip_start_date.to_s + ", for " + @trip_duration_days.to_s + " days in total. " + @trip_notes + ". Can you build day by day, activity by activity, what should i do"
    # ===========================================================================
    if the_trip.valid?
      the_trip.save
      # ===========================================================================
      i = AI::Chat.new
      i.system("You are an trip planner. Based on user's input of where and when they are travelling to, plus their specific requirements, come up with a trip plan with start time, end time, activity, and location for each day during the traveling period. Build day by day, activity by activity, detailed agenda")

      i.system(<<~SYS)
                  You are a trip-planner agent. Your job is to return **JSON only**, with no explanations, no markdown, and no extra text.

          Follow the schema *exactly*.  
          All fields must be present.  
          If information is unknown, make a reasonable assumption.

          The JSON must look exactly like this:
          {
            "days": [
              {
                "date": "YYYY-MM-DD",
                "items": [
                  {
                    "start_time": "HH:MM",
                    "end_time": "HH:MM",
                    "activity": "short description of the activity",
                    "plan_brief": "the name of the activity, no more than 4 words"
                    "location": "Name of the location as listed on Google Maps, including street, city, country, and zip code",
                    "commute": "1–2 sentence explanation of how to get there (walking, metro, taxi, etc.). Include reservation or ticket guidance ONLY if it is strongly recommended before arrival."
                  }
                ]
              }
            ]
          }
          
        Rules:
        - **date**: calendar date of that day of the trip
        - **start_time / end_time**: local time, 24-hour format "HH:MM"
        - **activity**: brief 1–2 sentence description of the activity
        - **plan_brief**: the name of the activity, no more than 4 words
        - **location**: Name of the location as listed on Google Maps, including street, city, country, and zip code
        - **commute**: brief 1–2 sentence note explaining how to get between items (walking, metro, taxi, etc.). Only include reservation or ticket guidance if they are strongly recommended before arrival—otherwise do not mention them

        Output **ONLY valid JSON** matching this structure.
      SYS

      i.user(@user_input)
      @response = i.generate!
      raw = @response[:content]          # JSON string from the model

      @plan = JSON.parse(raw, symbolize_names: true)

      ActiveRecord::Base.transaction do
        the_trip.trip_plans.destroy_all

        @plan[:days].each do |day|
          date = Date.parse(day[:date])

          day[:items].each do |item|
            TripPlan.create!(
              trip: the_trip,
              #trip_id: the_trip.id,
              date: date,
              start_time: Time.parse(item[:start_time]),
              end_time: Time.parse(item[:end_time]),
              trip_plan: item[:activity],
              plan_brief: item[:plan_brief],
              plan_location: item[:location],
              plan_details: item[:commute],
            )
          end
        end
      end
      # ===========================================================================
      #render template: "trip_templates/ai_agenda"
      redirect_to("/trips/#{the_trip.id}", { :notice => "Trip updated successfully." })
    else
      redirect_to("/trips/#{the_trip.id}", { :alert => the_trip.errors.full_messages.to_sentence })
    end
  end

  def create
    the_trip = Trip.new
    the_trip.user_id = current_user.id
    the_trip.trip_name = params.fetch("query_trip_name")
    the_trip.trip_location = params.fetch("query_trip_location")
    the_trip.trip_duration_days = params.fetch("query_trip_duration_days")
    the_trip.trip_start_date = params.fetch("query_trip_start_date")

    query_budget = params[:query_budget]
    summary_a = "Budget wise, I want my trip to be #{query_budget}" if query_budget.present?

    query_people = params[:query_people]
    summary_b = "I am #{query_people}" if query_people.present?

    query_todo = params[:query_todo]
    summary_c = "My trip should include a mix of these: #{query_todo}" if query_todo.present?

    live_area = params[:query_live_area]
    summary_d = "I stay near #{live_area}; and I can also go any other places you recommend" if live_area.present?

    trip_notes = params[:query_trip_notes]
    summary_e = "Specifically, I have these requirements: #{trip_notes}" if trip_notes.present?

    @summary = [summary_a, summary_b, summary_c, summary_d, summary_e].compact.join(" ; ")

    the_trip.trip_notes = @summary

    # ============================== AI Ouput ===================================
    require "bundler/setup"
    require "ai-chat"
    require "dotenv/load"
    require "json"
    require "time"

    @the_id = the_trip.id
    @trip_location = the_trip.trip_location
    @trip_duration_days = the_trip.trip_duration_days
    @trip_start_date = the_trip.trip_start_date
    @trip_notes = the_trip.trip_notes
    @trip_name = the_trip.trip_name

    @user_input = "I am traveling to " + @trip_location + ", from " + @trip_start_date.to_s + ", for " + @trip_duration_days.to_s + " days in total. " + @trip_notes + ". Can you build day by day, activity by activity, what should i do"
    # ===========================================================================
    if the_trip.valid?
      the_trip.save
      # ===========================================================================
      i = AI::Chat.new
      i.system("You are an trip planner. Based on user's input of where and when they are travelling to, plus their specific requirements, come up with a trip plan with start time, end time, activity, and location for each day during the traveling period. Build day by day, activity by activity, detailed agenda")

      i.system(<<~SYS)
                  You are a trip-planner agent. Your job is to return **JSON only**, with no explanations, no markdown, and no extra text.

          Follow the schema *exactly*.  
          All fields must be present.  
          If information is unknown, make a reasonable assumption.

          The JSON must look exactly like this:
          {
            "days": [
              {
                "date": "YYYY-MM-DD",
                "items": [
                  {
                    "start_time": "HH:MM",
                    "end_time": "HH:MM",
                    "activity": "short description of the activity",
                    "plan_brief": "the name of the activity, no more than 4 words"
                    "location": "Name of the location as listed on Google Maps, including street, city, country, and zip code",
                    "commute": "1–2 sentence explanation of how to get there (walking, metro, taxi, etc.). Include reservation or ticket guidance ONLY if it is strongly recommended before arrival."
                  }
                ]
              }
            ]
          }
          
        Rules:
        - **date**: calendar date of that day of the trip
        - **start_time / end_time**: local time, 24-hour format "HH:MM"
        - **activity**: brief 1–2 sentence description of the activity
        - **plan_brief**: the name of the activity, no more than 4 words
        - **location**: Name of the location as listed on Google Maps, including street, city, country, and zip code
        - **commute**: brief 1–2 sentence note explaining how to get between items (walking, metro, taxi, etc.). Only include reservation or ticket guidance if they are strongly recommended before arrival—otherwise do not mention them

        Output **ONLY valid JSON** matching this structure.
      SYS

      i.user(@user_input)
      @response = i.generate!
      raw = @response[:content]          # JSON string from the model

      @plan = JSON.parse(raw, symbolize_names: true)

      ActiveRecord::Base.transaction do
        the_trip.trip_plans.destroy_all

        @plan[:days].each do |day|
          date = Date.parse(day[:date])

          day[:items].each do |item|
            TripPlan.create!(
              trip: the_trip,
              #trip_id: the_trip.id,
              date: date,
              start_time: Time.parse(item[:start_time]),
              end_time: Time.parse(item[:end_time]),
              trip_plan: item[:activity],
              plan_brief: item[:plan_brief],
              user_id:the_trip.user_id,
              plan_location: item[:location],
              plan_details: item[:commute],
            )
          end
        end
      end
      # ===========================================================================
      #render template: "trip_templates/ai_agenda"
      redirect_to("/trips/#{the_trip.id}", { :notice => "Trip created successfully." })
    else
      redirect_to("/trips", { :alert => the_trip.errors.full_messages.to_sentence })
    end
  end
end

class TripsController < ApplicationController
  def index
    matching_trips = Trip.all

    @list_of_trips = matching_trips.order({ :created_at => :desc })

    render({ :template => "trip_templates/index" })
  end

  def show
    the_id = params.fetch("path_id")

    matching_trips = Trip.where({ :id => the_id })

    @the_trip = matching_trips.at(0)

    render({ :template => "trip_templates/show" })
  end



  def update_form
    the_id = params.fetch("path_id")

    matching_trips = Trip.where({ :id => the_id })

    @the_trip = matching_trips.at(0)

    render({ :template => "trip_templates/edit_trip" })
  end

  def update
    the_id = params.fetch("path_id")
    the_trip = Trip.where({ :id => the_id }).at(0)

    the_trip.trip_name = params.fetch("query_trip_name")
    the_trip.trip_location = params.fetch("query_trip_location")
    the_trip.trip_duration_days = params.fetch("query_trip_duration_days")
    the_trip.trip_start_date = params.fetch("query_trip_start_date")
    the_trip.trip_notes = params.fetch("query_trip_notes")

    if the_trip.valid?
      the_trip.save
      redirect_to("/trips/#{the_trip.id}", { :notice => "Trip updated successfully." })
    else
      redirect_to("/trips/#{the_trip.id}", { :alert => the_trip.errors.full_messages.to_sentence })
    end
  end

  def destroy
    the_id = params.fetch("path_id")
    the_trip = Trip.where({ :id => the_id }).at(0)

    the_trip.destroy

    redirect_to("/trips", { :notice => "Trip deleted successfully." })
  end


  def create
    the_trip = Trip.new
    the_trip.trip_name = params.fetch("query_trip_name")
    the_trip.trip_location = params.fetch("query_trip_location")
    the_trip.trip_duration_days = params.fetch("query_trip_duration_days")
    the_trip.trip_start_date = params.fetch("query_trip_start_date")
    the_trip.trip_notes = params.fetch("query_trip_notes")
    
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

    @user_input = "I am traveling to " + @trip_location + ", from " + @trip_start_date + ", for " + @trip_duration_days.to_s + " days in total, and specifically, I have these requirement: " + @trip_notes + "my trip name is: " + @trip_name +". Can you build day by day, activity by activity, what should i do"
# ===========================================================================
    if the_trip.valid?
      the_trip.save
# ===========================================================================      
      i = AI::Chat.new
      i.system("You are an trip planner. Based on user's input of where and when they are travelling to, plus their specific requirements, come up with a trip plan with start time, end time, activity, and location for each day during the traveling period. Build day by day, activity by activity, detailed agenda")

      i.system(<<~SYS)
      You are a trip planner. Based on the user's input, return a JSON object only,
      no markdown, no explanation.
      The JSON must look exactly like this:
      {
        "days": [
          {
            "date": "YYYY-MM-DD",
            "items": [
              {
                "start_time": "HH:MM",
                "end_time": "HH:MM",
                "activity": "short activity name",
                "location": "short location on google map / notes"
                "commute": "short location commute notes"
              }
            ]
          }
        ]
      }
      - date: the calendar date of that day of the trip
      - times: local time, 24-hour "HH:MM"
      - activity: 1–2 sentence description
      - location: short location name on google map
      - commute: 1–2 sentence notes on commuting to the location

      Output ONLY valid JSON that matches this schema.
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
          end_time:   Time.parse(item[:end_time]),
          trip_plan:  item[:activity],
          plan_location: item[:location]
          #plan_details: item[:commute]
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

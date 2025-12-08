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

  def create
    the_trip = Trip.new
    the_trip.trip_name = params.fetch("query_trip_name")
    the_trip.trip_location = params.fetch("query_trip_location")
    the_trip.trip_duration_days = params.fetch("query_trip_duration_days")
    the_trip.trip_start_date = params.fetch("query_trip_start_date")
    the_trip.trip_notes = params.fetch("query_trip_notes")

    if the_trip.valid?
      the_trip.save
      redirect_to("/trips/#{the_trip.id}", { :notice => "Trip created successfully." })
    else
      redirect_to("/trips", { :alert => the_trip.errors.full_messages.to_sentence })
    end
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

  def ai_ouput
    require "bundler/setup"
    require "ai-chat"
    require "dotenv/load"
    # the_id = params.fetch("path_id")
    the_id = 1
    the_trip = Trip.where({ :id => the_id }).at(0)
    @trip_location=the_trip.trip_location
    @trip_duration_days=the_trip.trip_duration_days	
    @trip_start_date=the_trip.trip_start_date	
    @trip_notes=the_trip.trip_notes
    @user_input = "Trip location is: " + @trip_location + ", the trip start date is: " + @trip_start_date + " ,for "+ @trip_duration_days.to_s + " days in total, and specifically, I have these requirement: "+ @trip_notes
    
    # i = AI::Chat.new
    # i.system("You are an trip planner. Based on user's input of where and when they are travelling to, plus their specific requirements, come up with a trip plan with start time, end time, activity, and location for each day during the traveling period.")
    # i.schema = '{"name": "trip_plans","strict": true,"schema": {"type": "object","properties": {"fat": {"type": "number","description": "The amount of fat in grams."},"protein": {"type": "number","description": "The amount of protein in grams."},"carbs": {"type": "number","description": "The amount of carbohydrates in grams."},"total_calories": {"type": "number","description": "The total calories calculated based on fat, protein, and carbohydrates."}},"required": ["fat","protein","carbs","total_calories"],"additionalProperties": false}}'

    # i.user(user_input)

    # @response = i.generate!
    # @data = @response[:content]                 # => {:fat=>15, :protein=>12, :carbs=>35, :total_calories=>285}
    # @data[:total_calories]  # => 285          # The response is parsed JSON, not a string!

    render({ :template => "trip_templates/ai_agenda" })
  end
end

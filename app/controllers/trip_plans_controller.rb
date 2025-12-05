class TripPlansController < ApplicationController
  def index
    matching_trip_plans = TripPlan.all

    @list_of_trip_plans = matching_trip_plans.order({ :created_at => :desc })

    render({ :template => "trip_plan_templates/index" })
  end

  def show
    the_id = params.fetch("path_id")

    matching_trip_plans = TripPlan.where({ :id => the_id })

    @the_trip_plan = matching_trip_plans.at(0)

    render({ :template => "trip_plan_templates/show" })
  end

  def create
    the_trip_plan = TripPlan.new
    the_trip_plan.trip_id = params.fetch("query_trip_id")
    the_trip_plan.trip_plan = params.fetch("query_trip_plan")
    the_trip_plan.start_time = params.fetch("query_start_time")
    the_trip_plan.end_time = params.fetch("query_end_time")
    the_trip_plan.date = params.fetch("query_date")
    the_trip_plan.plan_location = params.fetch("query_plan_location")
    the_trip_plan.plan_details = params.fetch("query_plan_details")

    if the_trip_plan.valid?
      the_trip_plan.save
      redirect_to("/trip_plans", { :notice => "Trip plan created successfully." })
    else
      redirect_to("/trip_plans", { :alert => the_trip_plan.errors.full_messages.to_sentence })
    end
  end

  def update
    the_id = params.fetch("path_id")
    the_trip_plan = TripPlan.where({ :id => the_id }).at(0)

    the_trip_plan.trip_id = params.fetch("query_trip_id")
    the_trip_plan.trip_plan = params.fetch("query_trip_plan")
    the_trip_plan.start_time = params.fetch("query_start_time")
    the_trip_plan.end_time = params.fetch("query_end_time")
    the_trip_plan.date = params.fetch("query_date")
    the_trip_plan.plan_location = params.fetch("query_plan_location")
    the_trip_plan.plan_details = params.fetch("query_plan_details")

    if the_trip_plan.valid?
      the_trip_plan.save
      redirect_to("/trip_plans/#{the_trip_plan.id}", { :notice => "Trip plan updated successfully." } )
    else
      redirect_to("/trip_plans/#{the_trip_plan.id}", { :alert => the_trip_plan.errors.full_messages.to_sentence })
    end
  end

  def destroy
    the_id = params.fetch("path_id")
    the_trip_plan = TripPlan.where({ :id => the_id }).at(0)

    the_trip_plan.destroy

    redirect_to("/trip_plans", { :notice => "Trip plan deleted successfully." } )
  end
end

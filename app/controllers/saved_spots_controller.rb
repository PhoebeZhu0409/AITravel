# frozen_string_literal: true

class SavedSpotsController < ApplicationController
  def create
    trip_plan = current_user.trip_plans.find(params[:trip_plan_id])
    current_user.saved_trip_plans.find_or_create_by!(trip_plan: trip_plan)
    GooglePlacesEnricher.ensure_place_thumbnail!(trip_plan)
    render json: { saved: true, trip_plan_id: trip_plan.id }
  end

  def update
    trip_plan = current_user.trip_plans.find(params[:trip_plan_id])
    saved = current_user.saved_trip_plans.find_by!(trip_plan: trip_plan)
    saved.update!(traveller_note: params.fetch(:traveller_note, ""))
    render json: { trip_plan_id: trip_plan.id, traveller_note: saved.traveller_note }
  end

  def destroy
    trip_plan = current_user.trip_plans.find(params[:trip_plan_id])
    current_user.saved_trip_plans.where(trip_plan: trip_plan).delete_all
    render json: { saved: false, trip_plan_id: trip_plan.id }
  end
end

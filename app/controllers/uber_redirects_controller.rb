# frozen_string_literal: true

# Look up a Google Place id, then send phones to the Uber app (website fallback).
class UberRedirectsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    address = params[:address].to_s.strip
    if address.blank?
      redirect_to(root_path, alert: "Missing destination for Uber.")
      return
    end

    name = params[:name].to_s.strip.presence
    lat = params[:lat]
    lng = params[:lng]
    place_id = params[:place_id].to_s.strip.presence
    formatted_address = nil

    if place_id.blank? || lat.blank? || lng.blank?
      details = GooglePlacesEnricher.find_place_details(address)
      if details.present?
        place_id ||= details[:place_id]
        name ||= details[:name]
        lat = lat.presence || details[:lat]
        lng = lng.presence || details[:lng]
        formatted_address = details[:formatted_address]
        persist_place_google_id(place_id)
      end
    end

    builder = UberDropoffUrl.new(
      address: address,
      name: name,
      lat: lat,
      lng: lng,
      place_id: place_id,
      formatted_address: formatted_address
    )

    @web_url = builder.universal
    @app_url = builder.app
    @ul_url = builder.ul
    @android_intent_url = builder.android_intent

    if mobile_browser?
      render :show, layout: false
    else
      response.set_header("Location", @web_url)
      head :see_other
    end
  end

  private

  def mobile_browser?
    request.user_agent.to_s.match?(/Android|iPhone|iPad|iPod/i)
  end

  def persist_place_google_id(place_id)
    return if place_id.blank?

    plan_id = params[:plan_id].to_s.strip
    return if plan_id.blank?

    TripPlan.where(id: plan_id, place_google_id: [nil, ""]).update_all(place_google_id: place_id)
  end
end

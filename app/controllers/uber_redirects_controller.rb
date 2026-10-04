# frozen_string_literal: true

# Same-origin hop so iOS WKWebView can intercept, then send the user to Uber with dropoff filled.
class UberRedirectsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    address = params[:address].to_s.strip
    if address.blank?
      redirect_to(root_path, alert: "Missing destination for Uber.")
      return
    end

    url = UberDropoffUrl.universal(
      address: address,
      name: params[:name],
      lat: params[:lat],
      lng: params[:lng]
    )
    redirect_to(url, allow_other_host: true, status: :see_other)
  end
end

# frozen_string_literal: true

# Ride-request links that actually prefill dropoff on phones.
# Nested drop[0] JSON on /looking is ignored in the Uber mobile webview.
class UberDropoffUrl
  def self.universal(address:, name: nil, lat: nil, lng: nil)
    new(address: address, name: name, lat: lat, lng: lng).universal
  end

  def self.app(address:, name: nil, lat: nil, lng: nil)
    new(address: address, name: name, lat: lat, lng: lng).app
  end

  def initialize(address:, name: nil, lat: nil, lng: nil)
    @address = address.to_s.strip
    @name = name.to_s.strip.presence || @address.split(",").first.to_s.strip
    @lat = lat
    @lng = lng
  end

  def universal
    "https://m.uber.com/ul/?#{query_string(universal_query)}"
  end

  def app
    "uber://riderequest?#{query_string(app_query)}"
  end

  private

  def has_coords?
    @lat.present? && @lng.present?
  end

  def universal_query
    q = {
      "action" => "setPickup",
      "pickup" => "my_location",
      "dropoff[formatted_address]" => @address
    }
    q["client_id"] = ENV["UBER_CLIENT_ID"].to_s.strip if ENV["UBER_CLIENT_ID"].to_s.strip.present?
    add_coords_and_name!(q)
    q
  end

  def app_query
    q = {
      "pickup" => "my_location",
      "dropoff[formatted_address]" => @address
    }
    add_coords_and_name!(q)
    q
  end

  def add_coords_and_name!(q)
    if has_coords?
      q["dropoff[latitude]"] = format_coord(@lat)
      q["dropoff[longitude]"] = format_coord(@lng)
    end
    q["dropoff[nickname]"] = @name if @name.present?
  end

  def format_coord(value)
    format("%.7f", value.to_f)
  end

  def query_string(query)
    query.map { |key, value| "#{ERB::Util.url_encode(key)}=#{ERB::Util.url_encode(value.to_s)}" }.join("&")
  end
end

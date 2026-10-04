# frozen_string_literal: true

# Working Uber web format (pickup page):
# /go/pickup?drop[0]=JSON&drop[0][addressLine1]=...&drop[0][addressLine2]=...
# JSON includes google_places id, source SEARCH, lat/lng, and provider.
class UberDropoffUrl
  def self.universal(address:, name: nil, lat: nil, lng: nil, place_id: nil, formatted_address: nil)
    new(
      address: address,
      name: name,
      lat: lat,
      lng: lng,
      place_id: place_id,
      formatted_address: formatted_address
    ).universal
  end

  def self.app(address:, name: nil, lat: nil, lng: nil, **_)
    new(address: address, name: name, lat: lat, lng: lng).app
  end

  def initialize(address:, name: nil, lat: nil, lng: nil, place_id: nil, formatted_address: nil)
    @address = address.to_s.strip
    @name = name.to_s.strip.presence || @address.split(",").first.to_s.strip
    @lat = lat
    @lng = lng
    @place_id = place_id.to_s.strip.presence
    @formatted_address = formatted_address.to_s.strip.presence
  end

  def universal
    line1 = @name.presence || @address
    nested_line2 = @address.presence || line1
    json = JSON.generate(location_payload(line1))
    [
      "https://m.uber.com/go/pickup?drop%5B0%5D=#{ERB::Util.url_encode(json)}",
      "drop%5B0%5D%5BaddressLine1%5D=#{ERB::Util.url_encode(line1)}",
      "drop%5B0%5D%5BaddressLine2%5D=#{ERB::Util.url_encode(nested_line2)}"
    ].join("&")
  end

  # Opens the native Uber app when installed (iOS/Android).
  def app
    "uber://riderequest?#{query_string(app_query)}"
  end

  # Universal link: phone OS hands this to the Uber app from Safari/Chrome.
  def ul
    "https://m.uber.com/ul/?#{query_string(app_query)}"
  end

  def android_intent
    fallback = ERB::Util.url_encode(universal)
    "intent://riderequest?#{query_string(app_query)}#Intent;scheme=uber;package=com.ubercab;S.browser_fallback_url=#{fallback};end"
  end

  private

  def location_payload(line1)
    loc = {
      "addressLine1" => line1,
      "addressLine2" => json_address_line2(line1)
    }
    loc["id"] = @place_id if @place_id.present?
    loc["source"] = "SEARCH"
    if has_coords?
      loc["latitude"] = @lat.to_f
      loc["longitude"] = @lng.to_f
    end
    loc["provider"] = "google_places"
    loc
  end

  def json_address_line2(line1)
    src = @formatted_address.presence || @address
    parts = src.split(",").map(&:strip).reject(&:blank?)
    parts.shift if parts.first&.casecmp?(line1)
    parts.pop if parts.last && country_name?(parts.last)
    line = parts.last(2).join(", ")
    line = line.sub(/\A\d{4,6}\s+/, "")
    line.presence || src
  end

  def country_name?(value)
    value.match?(
      /\A(Italy|Italia|France|Spain|España|Germany|Deutschland|United States|USA|UK|United Kingdom|Portugal|Brazil|Brasil|Japan|China|Mexico)\z/i
    )
  end

  def has_coords?
    @lat.present? && @lng.present?
  end

  def app_query
    q = {
      "action" => "setPickup",
      "pickup" => "my_location",
      "dropoff[formatted_address]" => @address
    }
    client_id = ENV["UBER_CLIENT_ID"].to_s.strip
    q["client_id"] = client_id if client_id.present?
    q["dropoff[nickname]"] = @name if @name.present?
    if has_coords?
      q["dropoff[latitude]"] = format("%.7f", @lat.to_f)
      q["dropoff[longitude]"] = format("%.7f", @lng.to_f)
    end
    q
  end

  def query_string(query)
    query.map { |key, value| "#{ERB::Util.url_encode(key)}=#{ERB::Util.url_encode(value.to_s)}" }.join("&")
  end
end

# frozen_string_literal: true

# Uber website ride page with destination in the query string.
# /looking and /ul/ are app universal links and often drop the destination.
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
    "https://m.uber.com/go/product-selection?#{web_query}"
  end

  def app
    "uber://riderequest?#{query_string(app_query)}"
  end

  def location_payload
    loc = {}
    if has_coords?
      loc["latitude"] = @lat.to_f
      loc["longitude"] = @lng.to_f
    end
    loc["addressLine1"] = @name.presence || @address
    loc["addressLine2"] = @address
    loc
  end

  private

  def has_coords?
    @lat.present? && @lng.present?
  end

  def web_query
    parts = []
    drop = location_payload
    drop.each do |key, value|
      parts << "drop%5B0%5D%5B#{ERB::Util.url_encode(key)}%5D=#{ERB::Util.url_encode(value.to_s)}"
    end
    parts << "drop%5B0%5D=#{ERB::Util.url_encode(JSON.generate(drop))}"
    parts.join("&")
  end

  def app_query
    q = {
      "action" => "setPickup",
      "pickup" => "my_location",
      "dropoff[formatted_address]" => @address
    }
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

# frozen_string_literal: true

# Public demo trips for /showcase/madrid and /showcase/new-york.
# Idempotent: safe to run on every deploy (bin/rails db:seed).
# Photos live as static assets under app/assets/images/showcase/{slug}/ (not Active Storage).

SHOWCASE_USER_EMAIL = "showcase@nalu.app"

showcase_user = User.find_or_create_by!(email: SHOWCASE_USER_EMAIL) do |user|
  user.password = SecureRandom.hex(32)
end

Dir[Rails.root.join("db/showcase/*.json")].sort.each do |path|
  data = JSON.parse(File.read(path))
  slug = data.fetch("showcase_slug")
  trip_attrs = data.fetch("trip").except("user_id")
  plan_attrs_list = data.fetch("plans").map { |attrs| attrs.except("user_id") }

  trip = Trip.find_or_initialize_by(showcase_slug: slug)
  trip.assign_attributes(trip_attrs.merge(user: showcase_user))
  trip.save!

  trip.trip_plans.destroy_all
  plan_attrs_list.each do |plan_attrs|
    trip.trip_plans.create!(plan_attrs.merge(user: showcase_user))
  end

  puts "Seeded showcase trip: #{slug} (#{trip.trip_plans.count} agenda items)"
end

# frozen_string_literal: true

# Static images for public /showcase/* trips (committed under app/assets/images/showcase/).
module ShowcaseImages
  IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .webp].freeze

  module_function

  def hero_asset_name(slug)
    find_asset("showcase/#{slug}/hero") if slug.present?
  end

  def plan_asset_name(slug, index)
    find_asset("showcase/#{slug}/plans/#{format('%02d', index)}") if slug.present? && index
  end

  def hero_bytes(slug)
    read_asset(hero_asset_name(slug))
  end

  def plan_bytes(slug, index)
    read_asset(plan_asset_name(slug, index))
  end

  def plan_index_for(trip, trip_plan)
    ordered = trip.trip_plans.order(:date, :start_time).to_a
    idx = ordered.index(trip_plan)
    idx ? idx + 1 : nil
  end

  def find_asset(relative_without_ext)
    IMAGE_EXTENSIONS.each do |ext|
      rel = "#{relative_without_ext}#{ext}"
      return rel if Rails.root.join("app/assets/images", rel).file?
    end
    nil
  end

  def read_asset(relative_path)
    return if relative_path.blank?

    path = Rails.root.join("app/assets/images", relative_path)
    return unless path.file?

    File.binread(path)
  end
  private_class_method :read_asset
end

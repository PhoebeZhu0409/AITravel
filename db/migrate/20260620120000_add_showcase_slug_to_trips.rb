# frozen_string_literal: true

class AddShowcaseSlugToTrips < ActiveRecord::Migration[8.0]
  def change
    add_column :trips, :showcase_slug, :string
    add_index :trips, :showcase_slug, unique: true, where: "showcase_slug IS NOT NULL"
  end
end

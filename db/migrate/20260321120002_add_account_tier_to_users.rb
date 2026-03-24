# frozen_string_literal: true

class AddAccountTierToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :account_tier, :string, null: false, default: "regular"
  end
end

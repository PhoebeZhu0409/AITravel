# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  username               :string
#  account_tier           :string           default("regular"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  ACCOUNT_TIERS = %w[regular premium].freeze
  REGULAR_GENERATION_LIMIT = 10
  GENERATION_WINDOW = 6.months

  has_many  :trip_plans, class_name: "TripPlan", foreign_key: "user_id"
  has_many  :trips, class_name: "Trip", foreign_key: "user_id"
  has_many  :trip_generation_events, dependent: :destroy

  validates :account_tier, inclusion: { in: ACCOUNT_TIERS }

  def premium?
    account_tier == "premium"
  end

  def regular?
    account_tier == "regular"
  end

  # Successful AI generations in the rolling window (create + rebuild).
  def trip_generations_used_in_window
    trip_generation_events.where("created_at > ?", self.class::GENERATION_WINDOW.ago).count
  end

  def can_generate_trip?
    return true if premium?

    trip_generations_used_in_window < self.class::REGULAR_GENERATION_LIMIT
  end

  def trip_generations_remaining
    return nil if premium?

    [0, self.class::REGULAR_GENERATION_LIMIT - trip_generations_used_in_window].max
  end

  # Call only after a successful itinerary generation (create or rebuild).
  def record_trip_generation!(trip:)
    return if premium?

    trip_generation_events.create!(trip: trip)
  end
end

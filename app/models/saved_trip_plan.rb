# frozen_string_literal: true

# == Schema Information
#
# Table name: saved_trip_plans
#
#  id             :bigint           not null, primary key
#  traveller_note :text             default(""), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  trip_plan_id   :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_saved_trip_plans_on_trip_plan_id              (trip_plan_id)
#  index_saved_trip_plans_on_user_id                   (user_id)
#  index_saved_trip_plans_on_user_id_and_trip_plan_id  (user_id,trip_plan_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (trip_plan_id => trip_plans.id)
#  fk_rails_...  (user_id => users.id)
#
class SavedTripPlan < ApplicationRecord
  belongs_to :user
  belongs_to :trip_plan

  validates :trip_plan_id, uniqueness: { scope: :user_id }
  validates :traveller_note, length: { maximum: 10_000 }
end

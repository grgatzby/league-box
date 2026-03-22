class TeamBoxScore < ApplicationRecord
  belongs_to :team
  belongs_to :box

  validates :team_id, uniqueness: { scope: :box_id }
end

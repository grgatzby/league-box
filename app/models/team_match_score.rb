class TeamMatchScore < ApplicationRecord
  belongs_to :team
  belongs_to :match

  validates :team_id, uniqueness: { scope: :match_id }
end

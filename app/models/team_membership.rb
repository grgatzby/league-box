class TeamMembership < ApplicationRecord
  belongs_to :team
  belongs_to :user
  belongs_to :round

  validates :team_id, uniqueness: { scope: :user_id }
  validates :user_id, uniqueness: { scope: :round_id }
  validate :team_round_consistency

  before_validation :assign_round_from_team

  private

  def assign_round_from_team
    self.round_id = team&.round_id
  end

  def team_round_consistency
    return unless team && round_id
    return if team.round_id == round_id

    errors.add(:round_id, "must match team round")
  end
end

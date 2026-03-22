class Team < ApplicationRecord
  belongs_to :round
  belongs_to :box, optional: true

  has_many :team_memberships, dependent: :destroy
  has_many :users, through: :team_memberships
  has_many :team_box_scores, dependent: :destroy
  has_many :team_match_scores, dependent: :destroy

  has_many :home_matches, class_name: "Match", foreign_key: :team_a_id, dependent: :nullify
  has_many :away_matches, class_name: "Match", foreign_key: :team_b_id, dependent: :nullify

  validates :round, presence: true
  validate :doubles_team_size_for_doubles_round

  def display_name
    pair_names = users.map(&:last_name).compact.map(&:strip).reject(&:empty?).sort
    return pair_names.join(" / ") if pair_names.any?
    return name if name.present?

    "Team ##{id}"
  end

  # Stable order for league table sorting (must match header "first name" / "surname" semantics).
  def sorted_players
    users.to_a.compact.sort_by { |u| [u.last_name.to_s.upcase, u.first_name.to_s.upcase] }
  end

  def first_player_for_sort
    sorted_players[0]
  end

  def second_player_for_sort
    sorted_players[1]
  end

  private

  def doubles_team_size_for_doubles_round
    return unless round&.doubles_format?
    return if team_memberships.size <= 2

    errors.add(:users, "cannot exceed 2 players for doubles")
  end
end

class Match < ApplicationRecord
  belongs_to :court
  belongs_to :box
  belongs_to :team_a, class_name: "Team", optional: true
  belongs_to :team_b, class_name: "Team", optional: true
  has_many :user_match_scores, dependent: :destroy
  has_many :team_match_scores, dependent: :destroy

  # the matches/new.html.erb form accepts nested attributes for user_match_scores
  accepts_nested_attributes_for :user_match_scores

  def doubles_match?
    team_a_id.present? && team_b_id.present?
  end

  def participants
    if doubles_match?
      [team_a, team_b]
    else
      user_match_scores.includes(:user).map(&:user)
    end
  end

  def user_allowed_to_submit_score?(user)
    return false unless user
    return true unless doubles_match?

    team_a.users.include?(user) || team_b.users.include?(user)
  end
end

class Round < ApplicationRecord
  scope :current, ->(today = Date.today) { where("start_date <= ? AND end_date >= ?", today, today) }
  belongs_to :club
  has_many :boxes, dependent: :destroy
  has_many :user_box_scores, through: :boxes

  # the rounds/new.html.erb form accepts nested attributes for boxes and user_box_scores
  accepts_nested_attributes_for :boxes

  validates :tiebreak_points, numericality: { greater_than_or_equal_to: 7 }, allow_nil: true

  # Returns the effective tiebreak points for this round
  # If tiebreak_points is set on the round, use it; otherwise inherit from club
  def effective_tiebreak_points
    tiebreak_points || club.tiebreak_points
  end
end

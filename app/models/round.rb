class Round < ApplicationRecord
  scope :current, ->(today = Date.today) { where("start_date <= ? AND end_date >= ?", today, today) }
  belongs_to :club
  has_many :boxes, dependent: :destroy
  has_many :user_box_scores, through: :boxes
end

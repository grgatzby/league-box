class Match < ApplicationRecord
  belongs_to :court
  belongs_to :box
  has_many :user_match_scores, dependent: :destroy
end

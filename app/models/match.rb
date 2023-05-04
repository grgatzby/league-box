class Match < ApplicationRecord
  belongs_to :court
  belongs_to :box
  has_many :user_match_scores, dependent: :destroy
  accepts_nested_attributes_for :user_match_scores
end

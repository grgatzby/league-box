class Box < ApplicationRecord
  belongs_to :round
  has_many :matches, dependent: :destroy
  has_many :user_box_scores, dependent: :destroy
end

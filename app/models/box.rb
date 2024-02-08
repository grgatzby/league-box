class Box < ApplicationRecord
  belongs_to :round
  belongs_to :chatroom
  has_many :matches, dependent: :destroy
  has_many :user_box_scores, dependent: :destroy

  accepts_nested_attributes_for :user_box_scores

  # def club
  #   self.round.club
  # end
end

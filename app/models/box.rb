class Box < ApplicationRecord
  belongs_to :round
  belongs_to :chatroom
  has_many :matches, dependent: :destroy
  has_many :user_box_scores, dependent: :destroy
  has_many :team_box_scores, dependent: :destroy
  has_many :teams, dependent: :destroy

  accepts_nested_attributes_for :user_box_scores

  # Stored Chatroom#name for this box. Uses Round#round_label (yyyy/mm_Rnn + S/D/P) before the ":Bnn" segment.
  # Example: "My Club - 2024/10_R01S:B03"
  def chatroom_label
    "#{round.club.name} - #{round.round_label}:B#{format('%02d', box_number)}"
  end

  # def club
  #   self.round.club
  # end
end

class UserBoxScore < ApplicationRecord
  belongs_to :user
  belongs_to :box

  # Used only on rounds#new form: proposed box move (+2 up … -2 down, 99 = leave next round).
  attr_accessor :promotion_move
end

class Round < ApplicationRecord
  belongs_to :club
  has_many :boxes, dependent: :destroy
end

class Club < ApplicationRecord
  has_many :rounds
  has_many :users
  has_many :courts
end

class Court < ApplicationRecord
  belongs_to :club
  has_many :matches, dependent: :destroy
end

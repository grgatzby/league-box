class Chatroom < ApplicationRecord
  has_many :messages, dependent: :destroy
  has_one :box

  # validates :box, presence: true
  validates :name, presence: true
  validates :name, uniqueness: true
end

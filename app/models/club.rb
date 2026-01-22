class Club < ApplicationRecord
  has_many :rounds, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :courts, dependent: :destroy
  has_many :gallery_images, dependent: :destroy

  mount_uploader :logo, ClubLogoUploader
  mount_uploader :banner, ClubBannerUploader

  validates :name, presence: true
  validates :name, uniqueness: true
  validates :tiebreak_points, presence: true, numericality: { greater_than_or_equal_to: 7 }

  before_validation :set_default_tiebreak_points, on: :create

  private

  def set_default_tiebreak_points
    self.tiebreak_points ||= 10
  end
end

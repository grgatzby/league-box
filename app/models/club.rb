class Club < ApplicationRecord
  has_many :rounds, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :courts, dependent: :destroy
  has_many :gallery_images, dependent: :destroy

  mount_uploader :logo, ClubLogoUploader
  mount_uploader :banner, ClubBannerUploader

  validates :name, presence: true
  validates :name, uniqueness: true
end

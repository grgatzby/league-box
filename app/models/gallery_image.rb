class GalleryImage < ApplicationRecord
  mount_uploader :image, GalleryImageUploader
  validates :caption, presence: true
  validates :image, presence: true
end

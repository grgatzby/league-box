class GalleryImage < ApplicationRecord
  mount_uploader :image, GalleryImageUploader
  belongs_to :club

  validates :caption, presence: true
  validates :image, presence: true, on: :create
  validates :club_id, presence: true

  # Scope to find images accessible to a specific club
  scope :accessible_to_club, ->(club_id) {
    where("? = ANY(accessible_club_ids)", club_id)
  }

  # Scope to find images from a specific club
  scope :from_club, ->(club_id) { where(club_id: club_id) }

  # Check if image is accessible to a club
  def accessible_to?(club_id)
    accessible_club_ids.empty? || accessible_club_ids.include?(club_id)
  end

  # Set default accessible clubs to uploader's club if not specified
  before_validation :set_default_accessible_clubs, on: :create

  private

  def set_default_accessible_clubs
    # If no clubs are selected, default to the uploader's club only
    if accessible_club_ids.blank? && club_id.present?
      self.accessible_club_ids = [club_id]
    end
  end
end

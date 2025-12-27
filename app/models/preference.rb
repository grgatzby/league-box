class Preference < ApplicationRecord
  belongs_to :user
  # Removed has_one_attached :photo - using CarrierWave on User model for profile pictures instead
end

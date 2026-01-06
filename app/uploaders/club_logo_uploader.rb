class ClubLogoUploader < CarrierWave::Uploader::Base
  include Cloudinary::CarrierWave

  # Store logo images in Cloudinary
  # Path structure: {environment}/league-box/gallery/club/{club_id}/{timestamp}_{club_name}_logo
  def public_id
    timestamp = Time.now.to_i
    club_id = model.id || 'temp'
    club_name = model.name.to_s.gsub(/[^a-zA-Z0-9\s]/, '').strip.gsub(/\s+/, '_')

    "#{Rails.env}/league-box/gallery/club/#{club_id}/#{timestamp}_#{club_name}_logo"
  end

  # Add an allowlist of extensions which are allowed to be uploaded.
  def extension_allowlist
    %w[jpg jpeg gif png webp]
  end
end

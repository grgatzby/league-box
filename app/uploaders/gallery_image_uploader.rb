class GalleryImageUploader < CarrierWave::Uploader::Base
  include Cloudinary::CarrierWave

  # Store images in the Gallery folder on Cloudinary
  # Path structure: {environment}/Gallery/{club_id}/{timestamp}_{caption_camelcase}
  def public_id
    timestamp = Time.now.to_i
    club_id = model.club_id || 'temp'
    caption_camel = caption_to_camel_case(model.caption)

    # Limit caption length to avoid very long filenames (max 50 chars)
    caption_camel = caption_camel[0..49] if caption_camel.length > 50

    "#{Rails.env}/gallery/club/#{club_id}/#{timestamp}_#{caption_camel}"
  end

  # Add an allowlist of extensions which are allowed to be uploaded.
  def extension_allowlist
    %w[jpg jpeg gif png webp]
  end

  private

  # Convert caption to camel case (e.g., "My Great Image!" => "MyGreatImage")
  def caption_to_camel_case(caption)
    return 'Image' if caption.blank?

    # Remove special characters, keep only alphanumeric and spaces
    cleaned = caption.to_s.gsub(/[^a-zA-Z0-9\s]/, '').strip
    return 'Image' if cleaned.blank?

    # Split by spaces, capitalize each word, join without spaces
    cleaned.split.map(&:capitalize).join
  end
end

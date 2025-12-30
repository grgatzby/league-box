class GalleryImageUploader < CarrierWave::Uploader::Base
  include Cloudinary::CarrierWave

  # Store images in the Gallery folder on Cloudinary
  # Path structure: {environment}/Gallery/{model_id}/{filename}
  def public_id
    "#{Rails.env}/Gallery/#{model.id}/#{mounted_as}"
  end

  # Add an allowlist of extensions which are allowed to be uploaded.
  def extension_allowlist
    %w[jpg jpeg gif png webp]
  end
end

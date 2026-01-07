module ApplicationHelper
  def profile_picture_circular_url(user, size = 50)
    return nil unless user.profile_picture.present?

    begin
      # Get the base URL from CarrierWave
      base_url = user.profile_picture.url.to_s

      # If it's already a Cloudinary URL, add transformations
      # Format: .../upload/TRANSFORMATIONS/public_id
      if base_url.include?('res.cloudinary.com')
        # Insert transformations before the public_id part
        # Transformations: c_thumb,g_face,w_SIZE,h_SIZE,r_max
        transformation = "c_thumb,g_face,w_#{size},h_#{size},r_max/"
        base_url.sub('/upload/', "/upload/#{transformation}")
      else
        base_url
      end
    rescue StandardError => e
      # Fallback to regular URL if transformation fails
      user.profile_picture.url.to_s
    end
  end

  def player_profile_picture_or_favicon(user, size = 30)
    if user.profile_picture.present?
      profile_picture_circular_url(user, size)
    elsif user.club&.logo.present?
      # Use club logo as fallback if available
      user.club.logo.url
    else
      image_path('favicon.png')
    end
  end
end

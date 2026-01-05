class UpdateGalleryImagePathsToNewCloudinaryStructure < ActiveRecord::Migration[7.0]
  def up
    # Update all gallery image paths from old structure to new structure
    # Extract public_id from full Cloudinary path and update to new structure
    # Old formats:
    #   - image/upload/v{version}/{env}/gallery/club/{club_id}/{rest} -> {env}/league-box/gallery/club/{club_id}/{rest}
    #   - image/upload/v{version}/{env}/Gallery/{club_id}/{rest} -> {env}/league-box/gallery/club/{club_id}/{rest}
    # New: {env}/league-box/gallery/club/{club_id}/{rest} (just the public_id, not full path)

    GalleryImage.find_each do |gallery_image|
      # Use read_attribute to get the raw stored value
      stored_value = gallery_image.read_attribute(:image)
      next if stored_value.blank?

      # Extract public_id from full path (remove image/upload/v{version}/ prefix if present)
      public_id = stored_value.sub(%r{^image/upload/v\d+/}, '')

      # If it's already just a public_id (doesn't start with image/upload), use it as is
      # Otherwise we've extracted it above
      new_public_id = nil

      # Pattern 1: {env}/gallery/club/{club_id}/... -> {env}/league-box/gallery/club/{club_id}/...
      if public_id.match?(%r{^[^/]+/gallery/club/})
        # Replace /gallery/club/ with /league-box/gallery/club/
        new_public_id = public_id.sub(%r{^([^/]+)/gallery/club/}, '\1/league-box/gallery/club/')
      # Pattern 2: {env}/Gallery/{club_id}/... -> {env}/league-box/gallery/club/{club_id}/...
      elsif public_id.match?(%r{^[^/]+/Gallery/\d+/})
        # Replace /Gallery/{club_id}/ with /league-box/gallery/club/{club_id}/
        new_public_id = public_id.sub(%r{^([^/]+)/Gallery/(\d+)/}, '\1/league-box/gallery/club/\2/')
      # Pattern 3: Already has league-box but still in full path format -> extract public_id
      elsif stored_value.match?(%r{^image/upload/v\d+/}) && public_id.include?('league-box/')
        # Already has league-box, just extract the public_id
        new_public_id = public_id
      end

      # Update if we have a new public_id and it's different from what's stored
      if new_public_id && new_public_id != stored_value && !new_public_id.match?(%r{^image/upload})
        gallery_image.update_column(:image, new_public_id)
      end
    end
  end

  def down
    # Revert paths back to old structure
    # New: {env}/league-box/gallery/club/{club_id}/{rest}
    # Old: {env}/gallery/club/{club_id}/{rest}

    GalleryImage.find_each do |gallery_image|
      # Use read_attribute to get the raw stored value (public_id)
      public_id = gallery_image.read_attribute(:image)
      next if public_id.blank? || !public_id.include?('league-box/')

      # Pattern: {env}/league-box/gallery/club/{club_id}/...
      if public_id.match?(%r{^[^/]+/league-box/gallery/club/})
        # Replace /league-box/gallery/club/ with /gallery/club/
        new_public_id = public_id.sub(%r{^([^/]+)/league-box/gallery/club/}, '\1/gallery/club/')
        gallery_image.update_column(:image, new_public_id)
      end
    end
  end
end

class AddClubAccessToGalleryImages < ActiveRecord::Migration[7.0]
  def change
    add_reference :gallery_images, :club, null: true, foreign_key: true
    add_column :gallery_images, :accessible_club_ids, :integer, array: true, default: []
    add_index :gallery_images, :accessible_club_ids, using: 'gin'

    # Set default club for existing records (use sample club)
    reversible do |dir|
      dir.up do
        sample_club = Club.find_by(name: "your tennis club")
        if sample_club
          execute "UPDATE gallery_images SET club_id = #{sample_club.id} WHERE club_id IS NULL"
        end
      end
    end

    # Make club_id required after setting defaults
    change_column_null :gallery_images, :club_id, false
  end
end

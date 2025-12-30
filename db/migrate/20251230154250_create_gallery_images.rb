class CreateGalleryImages < ActiveRecord::Migration[7.0]
  def change
    create_table :gallery_images do |t|
      t.string :image
      t.text :caption

      t.timestamps
    end
  end
end

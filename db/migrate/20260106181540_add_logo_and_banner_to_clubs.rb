class AddLogoAndBannerToClubs < ActiveRecord::Migration[7.0]
  def change
    add_column :clubs, :logo, :string
    add_column :clubs, :banner, :string
  end
end

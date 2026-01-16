class AddWebsiteToClubs < ActiveRecord::Migration[7.0]
  def change
    add_column :clubs, :website, :string
  end
end

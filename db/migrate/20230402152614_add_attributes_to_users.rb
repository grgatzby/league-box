class AddAttributesToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string
    add_column :users, :nickname, :string
    add_column :users, :phone_number, :string
    add_column :users, :is_manager, :boolean
    add_reference :users, :club, null: false, foreign_key: true
  end
end

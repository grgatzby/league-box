class RemoveIsManagerFromUsers < ActiveRecord::Migration[7.0]
  def change
    remove_column :users, :is_manager, :boolean
  end
end

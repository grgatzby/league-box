class RemoveFieldsFromUserBoxScores < ActiveRecord::Migration[7.0]
  def change
    remove_column :user_box_scores, :matches_won, :integer
    remove_column :user_box_scores, :matches_played, :integer
  end
end

class AddFieldsToUserBoxScores < ActiveRecord::Migration[7.0]
  def change
    add_column :user_box_scores, :sets_won, :integer
    add_column :user_box_scores, :sets_played, :integer
    add_column :user_box_scores, :games_won, :integer
    add_column :user_box_scores, :games_played, :integer
    add_column :user_box_scores, :matches_won, :integer
    add_column :user_box_scores, :matches_played, :integer
  end
end

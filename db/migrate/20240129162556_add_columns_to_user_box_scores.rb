class AddColumnsToUserBoxScores < ActiveRecord::Migration[7.0]
  def change
    add_column :user_box_scores, :games_won, :integer
    add_column :user_box_scores, :games_played, :integer
  end
end

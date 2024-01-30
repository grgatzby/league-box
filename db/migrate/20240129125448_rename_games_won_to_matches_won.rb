class RenameGamesWonToMatchesWon < ActiveRecord::Migration[7.0]
  def change
    rename_column :user_box_scores, :games_won, :matches_won
  end
end

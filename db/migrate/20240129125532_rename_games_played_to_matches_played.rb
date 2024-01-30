class RenameGamesPlayedToMatchesPlayed < ActiveRecord::Migration[7.0]
  def change
    rename_column :user_box_scores, :games_played, :matches_played
  end
end

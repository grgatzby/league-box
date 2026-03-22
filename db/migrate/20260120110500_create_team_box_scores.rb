class CreateTeamBoxScores < ActiveRecord::Migration[7.0]
  def change
    create_table :team_box_scores do |t|
      t.references :team, null: false, foreign_key: true
      t.references :box, null: false, foreign_key: true
      t.integer :points, default: 0, null: false
      t.integer :rank, default: 1, null: false
      t.integer :sets_won, default: 0, null: false
      t.integer :sets_played, default: 0, null: false
      t.integer :matches_won, default: 0, null: false
      t.integer :matches_played, default: 0, null: false
      t.integer :games_won, default: 0, null: false
      t.integer :games_played, default: 0, null: false

      t.timestamps
    end

    add_index :team_box_scores, [:team_id, :box_id], unique: true
  end
end

class CreateTeamMatchScores < ActiveRecord::Migration[7.0]
  def change
    create_table :team_match_scores do |t|
      t.references :team, null: false, foreign_key: true
      t.references :match, null: false, foreign_key: true
      t.integer :points, default: 0, null: false
      t.integer :score_set1, default: 0, null: false
      t.integer :score_set2, default: 0, null: false
      t.integer :score_tiebreak, default: 0, null: false
      t.boolean :is_winner, default: false, null: false
      t.integer :input_user_id
      t.datetime :input_date

      t.timestamps
    end

    add_index :team_match_scores, [:team_id, :match_id], unique: true
  end
end

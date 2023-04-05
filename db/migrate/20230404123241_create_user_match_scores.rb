class CreateUserMatchScores < ActiveRecord::Migration[7.0]
  def change
    create_table :user_match_scores do |t|
      t.integer :points
      t.integer :score_set1
      t.integer :score_set2
      t.integer :score_tiebreak
      t.boolean :is_winner
      t.references :user, null: false, foreign_key: true
      t.references :match, null: false, foreign_key: true

      t.timestamps
    end
  end
end

class CreateUserBoxScores < ActiveRecord::Migration[7.0]
  def change
    create_table :user_box_scores do |t|
      t.integer :points
      t.integer :rank
      t.references :user, null: false, foreign_key: true
      t.references :box, null: false, foreign_key: true

      t.timestamps
    end
  end
end

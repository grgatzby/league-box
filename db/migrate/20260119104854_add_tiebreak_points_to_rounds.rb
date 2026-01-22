class AddTiebreakPointsToRounds < ActiveRecord::Migration[7.0]
  def change
    add_column :rounds, :tiebreak_points, :integer, null: true
  end
end

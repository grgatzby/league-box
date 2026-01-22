class AddTiebreakPointsToClubs < ActiveRecord::Migration[7.0]
  def change
    add_column :clubs, :tiebreak_points, :integer, default: 10, null: false
    # Update existing clubs with default value
    Club.update_all(tiebreak_points: 10) if Club.table_exists?
  end
end

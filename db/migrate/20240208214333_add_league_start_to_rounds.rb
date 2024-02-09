class AddLeagueStartToRounds < ActiveRecord::Migration[7.0]
  def change
    add_column :rounds, :league_start, :date
  end
end

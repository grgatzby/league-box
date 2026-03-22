class AddTournamentFormatToRounds < ActiveRecord::Migration[7.0]
  def change
    add_column :rounds, :tournament_format, :string, null: false, default: "singles_tennis"
    add_index :rounds, :tournament_format
  end
end

class AddTeamReferencesToMatches < ActiveRecord::Migration[7.0]
  def change
    add_reference :matches, :team_a, null: true, foreign_key: { to_table: :teams }
    add_reference :matches, :team_b, null: true, foreign_key: { to_table: :teams }
  end
end

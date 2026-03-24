class EnforceOneTeamPerUserPerRound < ActiveRecord::Migration[7.0]
  class MigrationTeamMembership < ApplicationRecord
    self.table_name = "team_memberships"
  end

  def up
    add_reference :team_memberships, :round, foreign_key: true, null: true

    execute <<~SQL.squish
      UPDATE team_memberships
      SET round_id = teams.round_id
      FROM teams
      WHERE team_memberships.team_id = teams.id
    SQL

    remove_remaining_duplicate_memberships!

    change_column_null :team_memberships, :round_id, false
    add_index :team_memberships, [:user_id, :round_id], unique: true, name: "idx_team_memberships_user_round_unique"
  end

  def down
    remove_index :team_memberships, name: "idx_team_memberships_user_round_unique"
    remove_reference :team_memberships, :round, foreign_key: true
  end

  private

  def remove_remaining_duplicate_memberships!
    duplicates = MigrationTeamMembership
      .group(:user_id, :round_id)
      .having("COUNT(*) > 1")
      .pluck(:user_id, :round_id)

    duplicates.each do |user_id, round_id|
      memberships = MigrationTeamMembership.where(user_id: user_id, round_id: round_id).order(:id).to_a
      memberships.drop(1).each(&:destroy!)
    end
  end
end

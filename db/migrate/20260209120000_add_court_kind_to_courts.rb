# frozen_string_literal: true

class AddCourtKindToCourts < ActiveRecord::Migration[7.0]
  def up
    add_column :courts, :court_kind, :string, null: false, default: "tennis"
    add_index :courts, [:club_id, :court_kind]

    club = Club.find_by(id: 73)
    if club
      %w[1P 2P 3P 4P].each do |name|
        c = club.courts.find_or_initialize_by(name: name)
        c.court_kind = "padel"
        c.save!
      end

      court_1p = club.courts.find_by(name: "1P", court_kind: "padel")
      if court_1p
        Match.joins(box: :round)
             .where(rounds: { club_id: 73, tournament_format: "doubles_padel" })
             .where.not(court_id: court_1p.id)
             .update_all(court_id: court_1p.id)
      end
    end
  end

  def down
    remove_index :courts, [:club_id, :court_kind]
    remove_column :courts, :court_kind
  end
end

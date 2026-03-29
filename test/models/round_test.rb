require "test_helper"

class RoundTest < ActiveSupport::TestCase
  test "tournament format inclusion and doubles predicate" do
    club = Club.create!(name: "RoundTest Club #{SecureRandom.hex(4)}", tiebreak_points: 10)
    round = Round.new(
      club: club,
      start_date: Date.today - 1,
      end_date: Date.today + 20,
      league_start: Date.today.beginning_of_month
    )

    assert_equal "singles_tennis", round.tournament_format
    assert_not round.doubles_format?

    round.tournament_format = "doubles_tennis"
    assert round.valid?
    assert round.doubles_format?

    round.tournament_format = "not_supported"
    assert_not round.valid?
  end

  test "round_label includes format suffix and matches round_label_round_part" do
    club = Club.create!(name: "RoundLabel Club #{SecureRandom.hex(4)}", tiebreak_points: 10)
    league_start = Date.new(2024, 10, 1)
    r1 = Round.create!(
      club: club,
      start_date: league_start,
      end_date: league_start + 20,
      league_start: league_start,
      tournament_format: "singles_tennis"
    )
    r2 = Round.create!(
      club: club,
      start_date: league_start + 30,
      end_date: league_start + 50,
      league_start: league_start,
      tournament_format: "doubles_tennis"
    )

    I18n.with_locale(:en) do
      assert_equal "R01S", r1.round_label_round_part
      assert_equal "2024/10_R01S", r1.round_label

      assert_equal "R01D", r2.round_label_round_part
      assert_equal "2024/10_R01D", r2.round_label
    end

    padel = Round.create!(
      club: club,
      start_date: league_start + 60,
      end_date: league_start + 80,
      league_start: league_start,
      tournament_format: "doubles_padel"
    )
    I18n.with_locale(:en) do
      assert_equal "2024/10_R01P", padel.round_label
    end
  end

  test "round_number_in_league is per tournament_format: same start_date yields R01 for each format" do
    club = Club.create!(name: "RoundLabel Club #{SecureRandom.hex(4)}", tiebreak_points: 10)
    league_start = Date.new(2026, 3, 1)
    same_day = league_start
    padel = Round.create!(
      club: club,
      start_date: same_day,
      end_date: same_day + 20,
      league_start: league_start,
      tournament_format: "doubles_padel"
    )
    doubles = Round.create!(
      club: club,
      start_date: same_day,
      end_date: same_day + 20,
      league_start: league_start,
      tournament_format: "doubles_tennis"
    )
    I18n.with_locale(:en) do
      assert_equal "R01P", padel.round_label_round_part
      assert_equal "R01D", doubles.round_label_round_part
    end
  end
end

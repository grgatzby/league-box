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
end

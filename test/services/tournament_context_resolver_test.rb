require "test_helper"

class TournamentContextResolverTest < ActiveSupport::TestCase
  test "returns singles and doubles contexts for active rounds" do
    club = Club.create!(name: "Resolver Club #{SecureRandom.hex(4)}", tiebreak_points: 10)
    user = User.create!(
      email: "resolver_#{SecureRandom.hex(4)}@example.com",
      password: "123456",
      first_name: "Alice",
      last_name: "Player",
      phone_number: "0000000000",
      role: "player",
      club: club
    )

    singles_round = Round.create!(
      club: club,
      start_date: Date.today - 2,
      end_date: Date.today + 10,
      league_start: Date.today.beginning_of_month,
      tournament_format: "singles_tennis"
    )
    box = Box.create!(round: singles_round, box_number: 1, chatroom: Chatroom.find_or_create_by!(name: "general"))
    UserBoxScore.create!(user: user, box: box)

    doubles_round = Round.create!(
      club: club,
      start_date: Date.today - 2,
      end_date: Date.today + 10,
      league_start: Date.today.beginning_of_month,
      tournament_format: "doubles_tennis"
    )
    doubles_box = Box.create!(round: doubles_round, box_number: 2, chatroom: Chatroom.find_or_create_by!(name: "general"))
    team = Team.create!(round: doubles_round, box: doubles_box, name: "Team A")
    TeamMembership.create!(team: team, user: user)

    contexts = TournamentContextResolver.new(user).contexts
    formats = contexts.map { |ctx| ctx[:format] }

    assert_includes formats, "singles_tennis"
    assert_includes formats, "doubles_tennis"
  end
end

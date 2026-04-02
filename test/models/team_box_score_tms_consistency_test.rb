# frozen_string_literal: true

require "test_helper"

# Expected totals come from DoublesTeamBoxScoreTotals (same rules as MatchesController).
module TeamBoxScoreTmsAggregateHelper
  def assert_team_box_score_matches_team_match_scores(team, box)
    tbs = TeamBoxScore.find_by(team_id: team.id, box_id: box.id)
    assert tbs, "Expected TeamBoxScore for team_id=#{team.id} box_id=#{box.id}"

    expected = DoublesTeamBoxScoreTotals.totals_for_team_in_box(team, box)

    assert_equal expected[:points], tbs.points, "points mismatch for team #{team.id}"
    assert_equal expected[:games_won], tbs.games_won, "games_won mismatch for team #{team.id}"
    assert_equal expected[:games_played], tbs.games_played, "games_played mismatch for team #{team.id}"
    assert_equal expected[:sets_won], tbs.sets_won, "sets_won mismatch for team #{team.id}"
    assert_equal expected[:sets_played], tbs.sets_played, "sets_played mismatch for team #{team.id}"
    assert_equal expected[:matches_won], tbs.matches_won, "matches_won mismatch for team #{team.id}"
    assert_equal expected[:matches_played], tbs.matches_played, "matches_played mismatch for team #{team.id}"
  end
end

# Ensures TeamBoxScore aggregates stay aligned with TeamMatchScore rows for the same
# team in a box (doubles tennis / padel). Expected totals mirror MatchesController#apply_doubles_stats_delta.
# Singles: see user_box_score_ums_consistency_test.rb (UserMatchScore vs UserBoxScore).
class TeamBoxScoreTmsConsistencyTest < ActiveSupport::TestCase
  include TeamBoxScoreTmsAggregateHelper

  test "team_box_score matches aggregate derived from team_match_scores after apply_doubles_stats_delta (doubles tennis)" do
    club = Club.create!(name: "TBS Consistency Club #{SecureRandom.hex(4)}", tiebreak_points: 10)
    court = Court.create!(club: club, name: "1", court_kind: "tennis")
    round = Round.create!(
      club: club,
      start_date: Date.today - 1,
      end_date: Date.today + 20,
      league_start: Date.today.beginning_of_month,
      tournament_format: "doubles_tennis"
    )
    box = Box.create!(round: round, box_number: 1)

    users = 4.times.map do |i|
      User.create!(
        email: "tbs_consistency_#{SecureRandom.hex(4)}_#{i}@example.com",
        password: "123456",
        first_name: "P#{i}",
        last_name: "User",
        phone_number: "0000000000",
        role: "player",
        club: club
      )
    end

    team_a = Team.create!(round: round, box: box, name: "Team A")
    team_b = Team.create!(round: round, box: box, name: "Team B")
    users[0..1].each { |u| TeamMembership.create!(team: team_a, user: u) }
    users[2..3].each { |u| TeamMembership.create!(team: team_b, user: u) }

    users.each do |u|
      UserBoxScore.create!(
        user: u,
        box: box,
        points: 0, rank: 1,
        sets_won: 0, sets_played: 0, matches_won: 0, matches_played: 0,
        games_won: 0, games_played: 0
      )
    end

    TeamBoxScore.create!(
      team: team_a, box: box,
      points: 0, rank: 1,
      sets_won: 0, sets_played: 0, matches_won: 0, matches_played: 0,
      games_won: 0, games_played: 0
    )
    TeamBoxScore.create!(
      team: team_b, box: box,
      points: 0, rank: 1,
      sets_won: 0, sets_played: 0, matches_won: 0, matches_played: 0,
      games_won: 0, games_played: 0
    )

    controller = MatchesController.new
    match_scores = [
      { score_set1: 4, score_set2: 4, score_tiebreak: 0 },
      { score_set1: 2, score_set2: 1, score_tiebreak: 0 }
    ]
    controller.send(:compute_points, match_scores)
    results = controller.send(:compute_results, match_scores)

    match = Match.create!(
      box: box,
      court: court,
      team_a: team_a,
      team_b: team_b,
      time: Time.current
    )

    TeamMatchScore.create!(
      team_id: team_a.id,
      match_id: match.id,
      score_set1: match_scores[0][:score_set1],
      score_set2: match_scores[0][:score_set2],
      score_tiebreak: match_scores[0][:score_tiebreak],
      points: match_scores[0][:points],
      is_winner: results[0] > results[1]
    )
    TeamMatchScore.create!(
      team_id: team_b.id,
      match_id: match.id,
      score_set1: match_scores[1][:score_set1],
      score_set2: match_scores[1][:score_set2],
      score_tiebreak: match_scores[1][:score_tiebreak],
      points: match_scores[1][:points],
      is_winner: results[1] > results[0]
    )

    controller.send(:apply_doubles_stats_delta, match, match_scores, results, 1)

    assert_team_box_score_matches_team_match_scores(team_a, box)
    assert_team_box_score_matches_team_match_scores(team_b, box)
  end

  test "team_box_score matches aggregate derived from team_match_scores (doubles padel)" do
    club = Club.create!(name: "TBS Padel Club #{SecureRandom.hex(4)}", tiebreak_points: 10)
    court = Court.create!(club: club, name: "1P", court_kind: "padel")
    round = Round.create!(
      club: club,
      start_date: Date.today - 1,
      end_date: Date.today + 20,
      league_start: Date.today.beginning_of_month,
      tournament_format: "doubles_padel"
    )
    box = Box.create!(round: round, box_number: 1)

    users = 4.times.map do |i|
      User.create!(
        email: "tbs_padel_#{SecureRandom.hex(4)}_#{i}@example.com",
        password: "123456",
        first_name: "P#{i}",
        last_name: "User",
        phone_number: "0000000000",
        role: "player",
        club: club
      )
    end

    team_a = Team.create!(round: round, box: box, name: "Padel A")
    team_b = Team.create!(round: round, box: box, name: "Padel B")
    users[0..1].each { |u| TeamMembership.create!(team: team_a, user: u) }
    users[2..3].each { |u| TeamMembership.create!(team: team_b, user: u) }

    users.each do |u|
      UserBoxScore.create!(
        user: u,
        box: box,
        points: 0, rank: 1,
        sets_won: 0, sets_played: 0, matches_won: 0, matches_played: 0,
        games_won: 0, games_played: 0
      )
    end

    TeamBoxScore.create!(
      team: team_a, box: box,
      points: 0, rank: 1,
      sets_won: 0, sets_played: 0, matches_won: 0, matches_played: 0,
      games_won: 0, games_played: 0
    )
    TeamBoxScore.create!(
      team: team_b, box: box,
      points: 0, rank: 1,
      sets_won: 0, sets_played: 0, matches_won: 0, matches_played: 0,
      games_won: 0, games_played: 0
    )

    controller = MatchesController.new
    # Straight 2–0 set win (avoid 1–1 + empty tiebreak, which leaves points ambiguous in compute_points).
    match_scores = [
      { score_set1: 4, score_set2: 4, score_tiebreak: 0 },
      { score_set1: 1, score_set2: 2, score_tiebreak: 0 }
    ]
    controller.send(:compute_points, match_scores)
    results = controller.send(:compute_results, match_scores)

    match = Match.create!(
      box: box,
      court: court,
      team_a: team_a,
      team_b: team_b,
      time: Time.current
    )

    TeamMatchScore.create!(
      team_id: team_a.id,
      match_id: match.id,
      score_set1: match_scores[0][:score_set1],
      score_set2: match_scores[0][:score_set2],
      score_tiebreak: match_scores[0][:score_tiebreak],
      points: match_scores[0][:points],
      is_winner: results[0] > results[1]
    )
    TeamMatchScore.create!(
      team_id: team_b.id,
      match_id: match.id,
      score_set1: match_scores[1][:score_set1],
      score_set2: match_scores[1][:score_set2],
      score_tiebreak: match_scores[1][:score_tiebreak],
      points: match_scores[1][:points],
      is_winner: results[1] > results[0]
    )

    controller.send(:apply_doubles_stats_delta, match, match_scores, results, 1)

    assert_team_box_score_matches_team_match_scores(team_a, box)
    assert_team_box_score_matches_team_match_scores(team_b, box)
  end
end

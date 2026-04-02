# frozen_string_literal: true

require "test_helper"

# Recomputes UserBoxScore totals from UserMatchScore rows for singles matches in a box,
# mirroring MatchesController#create_scores (singles import) / singles score creation.
module UserBoxScoreUmsAggregateHelper
  def assert_user_box_score_matches_user_match_scores(user, box, controller)
    ubs = UserBoxScore.find_by(user_id: user.id, box_id: box.id)
    assert ubs, "Expected UserBoxScore for user_id=#{user.id} box_id=#{box.id}"

    expected = aggregate_expected_user_box_score_from_matches(user, box, controller)

    assert_equal expected[:points], ubs.points, "points mismatch for user #{user.id}"
    assert_equal expected[:games_won], ubs.games_won, "games_won mismatch for user #{user.id}"
    assert_equal expected[:games_played], ubs.games_played, "games_played mismatch for user #{user.id}"
    assert_equal expected[:sets_won], ubs.sets_won, "sets_won mismatch for user #{user.id}"
    assert_equal expected[:sets_played], ubs.sets_played, "sets_played mismatch for user #{user.id}"
    assert_equal expected[:matches_won], ubs.matches_won, "matches_won mismatch for user #{user.id}"
    assert_equal expected[:matches_played], ubs.matches_played, "matches_played mismatch for user #{user.id}"
  end

  def aggregate_expected_user_box_score_from_matches(user, box, controller)
    expected = {
      points: 0,
      games_won: 0,
      games_played: 0,
      sets_won: 0,
      sets_played: 0,
      matches_won: 0,
      matches_played: 0
    }

    Match.where(box_id: box.id)
         .joins(:user_match_scores)
         .where(user_match_scores: { user_id: user.id })
         .distinct
         .order(:id)
         .each do |match|
      ums_list = match.user_match_scores.order(:id).to_a
      next if ums_list.size < 2

      match_scores = [
        {
          score_set1: ums_list[0].score_set1.to_i,
          score_set2: ums_list[0].score_set2.to_i,
          score_tiebreak: ums_list[0].score_tiebreak.to_i
        },
        {
          score_set1: ums_list[1].score_set1.to_i,
          score_set2: ums_list[1].score_set2.to_i,
          score_tiebreak: ums_list[1].score_tiebreak.to_i
        }
      ]
      results = controller.send(:compute_results, match_scores)

      idx = ums_list[0].user_id == user.id ? 0 : 1
      ums = ums_list[idx]
      other = ums_list[1 - idx]

      own_games = controller.send(:won_games, ums)
      opp_games = controller.send(:won_games, other)

      expected[:points] += ums.points.to_i
      expected[:games_won] += own_games.to_i
      expected[:games_played] += own_games.to_i + opp_games.to_i
      expected[:sets_won] += results[idx].to_i
      expected[:sets_played] += results.sum
      expected[:matches_won] += results[idx] > results[1 - idx] ? 1 : 0
      expected[:matches_played] += 1
    end

    expected
  end

  # Applies the same UserBoxScore increments as MatchesController#create_scores (singles branch).
  def apply_singles_match_to_user_box_scores!(match, match_scores, results, controller)
    user_match_scores = match.user_match_scores.order(:id).to_a
    [0, 1].each do |index|
      ums = user_match_scores[index]
      user_box_score = UserBoxScore.find_by(box_id: match.box_id, user_id: ums.user_id)
      next unless user_box_score

      user_box_score.points = user_box_score.points.to_i + ums.points.to_i
      user_box_score.games_won = user_box_score.games_won.to_i + controller.send(:won_games, ums).to_i
      user_box_score.games_played = user_box_score.games_played.to_i +
                                    controller.send(:won_games, ums).to_i +
                                    controller.send(:won_games, user_match_scores[1 - index]).to_i
      user_box_score.sets_won = user_box_score.sets_won.to_i + results[index].to_i
      user_box_score.sets_played = user_box_score.sets_played.to_i + results.sum
      user_box_score.matches_won = user_box_score.matches_won.to_i + (results[index] > results[1 - index] ? 1 : 0)
      user_box_score.matches_played = user_box_score.matches_played.to_i + 1
      user_box_score.save!
    end
  end
end

class UserBoxScoreUmsConsistencyTest < ActiveSupport::TestCase
  include UserBoxScoreUmsAggregateHelper

  test "user_box_score matches aggregate derived from user_match_scores (singles tennis)" do
    club = Club.create!(name: "UBS Singles Club #{SecureRandom.hex(4)}", tiebreak_points: 10)
    court = Court.create!(club: club, name: "1", court_kind: "tennis")
    round = Round.create!(
      club: club,
      start_date: Date.today - 1,
      end_date: Date.today + 20,
      league_start: Date.today.beginning_of_month,
      tournament_format: "singles_tennis"
    )
    box = Box.create!(round: round, box_number: 1)

    player = User.create!(
      email: "ubs_singles_a_#{SecureRandom.hex(4)}@example.com",
      password: "123456",
      first_name: "Alex",
      last_name: "Player",
      phone_number: "0000000000",
      role: "player",
      club: club
    )
    opponent = User.create!(
      email: "ubs_singles_b_#{SecureRandom.hex(4)}@example.com",
      password: "123456",
      first_name: "Bob",
      last_name: "Opponent",
      phone_number: "0000000000",
      role: "player",
      club: club
    )

    [player, opponent].each do |u|
      UserBoxScore.create!(
        user: u,
        box: box,
        points: 0, rank: 1,
        sets_won: 0, sets_played: 0, matches_won: 0, matches_played: 0,
        games_won: 0, games_played: 0
      )
    end

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
      team_a_id: nil,
      team_b_id: nil,
      time: Time.current
    )

    UserMatchScore.create!(user_id: player.id, match_id: match.id)
    UserMatchScore.create!(user_id: opponent.id, match_id: match.id)

    ums_ordered = match.user_match_scores.order(:id).to_a
    [0, 1].each do |index|
      ums_ordered[index].update!(
        score_set1: match_scores[index][:score_set1],
        score_set2: match_scores[index][:score_set2],
        score_tiebreak: match_scores[index][:score_tiebreak],
        points: match_scores[index][:points],
        is_winner: results[index] > results[1 - index]
      )
    end

    apply_singles_match_to_user_box_scores!(match.reload, match_scores, results, controller)

    assert_user_box_score_matches_user_match_scores(player, box, controller)
    assert_user_box_score_matches_user_match_scores(opponent, box, controller)
  end
end

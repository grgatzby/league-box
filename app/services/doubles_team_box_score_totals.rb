# frozen_string_literal: true

# Pure recomputation of doubles TeamBoxScore aggregates from TeamMatchScore rows for matches
# in a box. Mirrors MatchesController#apply_doubles_stats_delta (+1 from zero) so drifted rows
# can be repaired (e.g. after bugs in match destroy or partial imports).
module DoublesTeamBoxScoreTotals
  module_function

  # @return [Hash] keys: :points, :games_won, :games_played, :sets_won, :sets_played, :matches_won, :matches_played
  def totals_for_team_in_box(team, box)
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
         .where("team_a_id = ? OR team_b_id = ?", team.id, team.id)
         .order(:id)
         .each do |match|
      payloads = payloads_from_match(match)
      results = compute_results(payloads)
      idx = match.team_a_id == team.id ? 0 : 1
      ms = payloads[idx]
      own_games = ms[:score_set1] + ms[:score_set2] + ms[:score_tiebreak]
      opp = payloads[1 - idx]
      opp_games = opp[:score_set1] + opp[:score_set2] + opp[:score_tiebreak]
      won_match = results[idx] > results[1 - idx] ? 1 : 0

      expected[:points] += ms[:points].to_i
      expected[:games_won] += own_games.to_i
      expected[:games_played] += own_games.to_i + opp_games.to_i
      expected[:sets_won] += results[idx].to_i
      expected[:sets_played] += results.sum
      expected[:matches_won] += won_match
      expected[:matches_played] += 1
    end

    expected
  end

  def payloads_from_match(match)
    team_scores = match.team_match_scores.index_by(&:team_id)
    [match.team_a_id, match.team_b_id].map do |team_id|
      tms = team_scores[team_id]
      {
        score_set1: tms&.score_set1.to_i,
        score_set2: tms&.score_set2.to_i,
        score_tiebreak: tms&.score_tiebreak.to_i,
        points: tms&.points.to_i
      }
    end
  end

  # Same as MatchesController#compute_results for two side hashes (no :points required).
  def compute_results(match_scores)
    results = { sets_won1: 0, sets_won2: 0 }

    if match_scores[0][:score_set1] > match_scores[1][:score_set1]
      results[:sets_won1] += 1
    elsif match_scores[0][:score_set1] < match_scores[1][:score_set1]
      results[:sets_won2] += 1
    end

    if match_scores[0][:score_set2] > match_scores[1][:score_set2]
      results[:sets_won1] += 1
    elsif match_scores[0][:score_set2] < match_scores[1][:score_set2]
      results[:sets_won2] += 1
    end

    if results[:sets_won1] == 1 && results[:sets_won2] == 1
      if match_scores[0][:score_tiebreak] > match_scores[1][:score_tiebreak]
        results[:sets_won1] += 1
      elsif match_scores[0][:score_tiebreak] < match_scores[1][:score_tiebreak]
        results[:sets_won2] += 1
      end
    end

    [results[:sets_won1], results[:sets_won2]]
  end
end

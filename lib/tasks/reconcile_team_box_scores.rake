# frozen_string_literal: true

def team_box_score_totals_match?(tbs, totals)
  %i[points games_won games_played sets_won sets_played matches_won matches_played].all? do |k|
    tbs.read_attribute(k).to_i == totals[k].to_i
  end
end

def team_box_score_totals_snapshot(tbs)
  {
    points: tbs.points.to_i,
    games_won: tbs.games_won.to_i,
    games_played: tbs.games_played.to_i,
    sets_won: tbs.sets_won.to_i,
    sets_played: tbs.sets_played.to_i,
    matches_won: tbs.matches_won.to_i,
    matches_played: tbs.matches_played.to_i
  }
end

namespace :data_fixes do
  desc <<-DESC.squish
    Recompute all TeamBoxScore columns from TeamMatchScore rows (fixes drift).
    By default processes every team_box_score. Set TEAM_BOX_SCORE_ID=<id> to limit to one row.
    DRY_RUN=1 prints rows that would change without updating. VERBOSE=1 lists every row processed.
  DESC
  task reconcile_team_box_scores: :environment do
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV["DRY_RUN"])
    verbose = ActiveModel::Type::Boolean.new.cast(ENV["VERBOSE"])

    scope = if ENV["TEAM_BOX_SCORE_ID"].present?
              TeamBoxScore.where(id: ENV["TEAM_BOX_SCORE_ID"].to_i)
            else
              TeamBoxScore.all
            end

    if scope.empty?
      puts "No TeamBoxScore rows matched."
      exit 0
    end

    boxes = {}
    processed = 0
    changed = 0

    scope.includes(:team, :box).find_each do |tbs|
      totals = DoublesTeamBoxScoreTotals.totals_for_team_in_box(tbs.team, tbs.box)
      processed += 1

      if team_box_score_totals_match?(tbs, totals)
        if verbose
          puts "TeamBoxScore id=#{tbs.id} team_id=#{tbs.team_id} box_id=#{tbs.box_id} (unchanged)"
        end
      else
        changed += 1
        label = "TeamBoxScore id=#{tbs.id} team_id=#{tbs.team_id} box_id=#{tbs.box_id}"
        if dry_run
          puts "#{label} would change:"
          puts "  from: #{team_box_score_totals_snapshot(tbs)}"
          puts "  to:   #{totals.inspect}"
        else
          puts "#{label} -> #{totals.inspect}"
          tbs.update!(totals)
          boxes[tbs.box_id] = tbs.box
        end
      end
    end

    unless dry_run
      ranker = ApplicationController.new
      boxes.each_value do |box|
        ranker.send(:rank_teams, box.team_box_scores.reload.to_a)
        puts "Re-ranked teams for box_id=#{box.id}"
      end
    end

    puts "Done. Processed #{processed} team_box_score(s), #{changed} mismatch(es)#{" (dry run — no writes)" if dry_run}."
  end
end

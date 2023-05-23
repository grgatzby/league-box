class UserBoxScoresController < ApplicationController
  def index
    set_club_and_round
    @user_box_scores = rank_players(@round.user_box_scores) if @round
    @rules = "A player's league position is determined by the total number of points won in a Round.
              In the event that two or more players have the same number of points the league position will be
              determined by:<br />
              1. Head to Head result (if only 2 players on the same score)<br />
              2. Most matches played<br />
              3. Ratio of Sets Won to Sets Played<br />
              4. Ratio of Games Won to Games Played"
  end

  private

  def rank_players(scores)
    @tieds = [] # populated in #add_to_tieds
    scores = scores.sort { |a, b| compare(a, b) }
    # updates the rank field in the UserBoxScore database

    # previous ranking (flawed), based on points only :

    # points_array = scores.map(&:points)
    # sorted_points = points_array.sort.uniq.reverse
    # scores.each do |score|
    #   score.update(rank: sorted_points.index(score.points) + 1)
    # end

    # new ranking based on sorting criterias and ties :

    rank_tied = 1
    player = scores.first
    ranks = scores.map do |score|
      rank_tied = scores.index(score) + 1 unless @tieds.include?(score) && compare(player, score).zero?
      player = score
      rank_tied
    end
    scores.each_with_index { |score, index| score.update(rank: ranks[index]) }
  end

  def compare(a, b)
    comparison = compare_points(a, b)
    return comparison unless comparison.zero?

    comparison = compare_matches_played(a, b)
    return comparison unless comparison.zero?

    comparison = compare_set_ratio(a, b)
    return comparison unless comparison.zero?

    comparison = compare_game_ratio(a, b)
    return comparison unless comparison.zero?

    add_to_tieds(a, b)

    comparison
  end

  def compare_points(a, b)
    b.points <=> a.points
  end

  def compare_matches_played(a, b)
    b.games_played <=> a.games_played
  end

  def compare_set_ratio(a, b)
    (b.sets_played.zero? ? 0 : b.sets_won.to_f / b.sets_played) <=> (a.sets_played.zero? ? 0 : a.sets_won.to_f / a.sets_played)
  end

  def compare_game_ratio(a, b)
    (b.games_played.zero? ? 0 : b.games_won.to_f / b.games_played) <=> (a.games_played.zero? ? 0 : a.games_won.to_f / a.games_played)
  end

  def add_to_tieds(*players)
    players.each { |player| @tieds << player }
    @tieds.uniq!
  end
end

class UserBoxScoresController < ApplicationController
  def index
    set_club_and_round
    if @round
      @scores = @round.user_box_scores
      @rules = "A player's league position is determined by the total number of points won in a Round.
                In the event that two or more players have the same number of points the league position will be
                determined by:<br />
                1. Head to Head result (if only 2 players on the same score)<br />
                2. Most matches played<br />
                3. Ratio of Sets Won to Sets Played<br />
                4. Ratio of Games Won to Games Played"
      @tied_players = []
      @scores = @scores.sort { |a, b| compare_players(a, b) }
      # updates the rank field in the database

      # previous ranking, based on points only

      # points_array = @scores.map(&:points)
      # sorted_points = points_array.sort.uniq.reverse
      # @scores.each do |user_box_score|
      #   user_box_score.update(rank: sorted_points.index(user_box_score.points) + 1)
      # end

      # new ranking based on sorting criterias and ties

      rank_tied = 1
      player = @scores.first
      sort_array = @scores.map do |score|
        unless @tied_players.include?(score) && compare_players(player, score).zero?
          rank_tied = @scores.index(score) + 1
        end
        player = score
        rank_tied
      end

      @scores.each_with_index do |user_box_score, index|
        user_box_score.update(rank: sort_array[index])
      end
    end
  end

  private

  def compare_players(a, b)
    comparison = compare_points(a, b)
    return comparison unless comparison.zero?

    comparison = compare_matches_played(a, b)
    return comparison unless comparison.zero?

    comparison = compare_set_ratio(a, b)
    return comparison unless comparison.zero?

    comparison = compare_game_ratio(a, b)
    return comparison unless comparison.zero?

    add_to_tied_players(a, b)

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

  def add_to_tied_players(*players)
    players.each { |player| @tied_players << player }
    @tied_players.uniq!
  end
end

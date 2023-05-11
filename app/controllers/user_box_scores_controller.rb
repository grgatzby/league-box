class UserBoxScoresController < ApplicationController
  def index
    set_club_and_round
    if @round
      @scores = @round.user_box_scores
      # A player's league position is determined by the total number of points won in a Round.
      # In the event that two or more players have the same number of points the league position will be
      # determined by
      # 1. Head to Head result (if only 2 players on the same score)
      # 2. Most matches played
      # 3. Ratio of Sets Won to Sets Played
      # 4. Ratio of Games Won to Games Played
      @scores = @scores.sort do |a, b|
        [b.points, b.games_played,
         (b.sets_played.zero? ? 0 : b.sets_won / b.sets_played),
         (b.games_played.zero? ? 0 : b.games_won / b.games_played)] <=>
          [a.points, a.games_played,
           (a.sets_played.zero? ? 0 : a.sets_won / a.sets_played),
           (a.games_played.zero? ? 0 : a.games_won/a.games_played)]
      end
      # updates the rank field in the database
      points_array = @scores.map(&:points)
      sorted_points = points_array.sort.uniq.reverse
      @scores.each do |user_box_score|
        user_box_score.update(rank: sorted_points.index(user_box_score.points) + 1)
      end
    end
  end
end

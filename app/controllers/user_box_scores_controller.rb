class UserBoxScoresController < ApplicationController
  def index
    @scores = UserBoxScore.all
    # display players sorted by descending Total number of points
    @scores = @scores.sort {|a, b| [b.points, b.user.user_match_scores.count] <=> [a.points, a.user.user_match_scores.count] }
    # populate rank in the database
    points_array = @scores.map(&:points)
    sorted_points = points_array.sort.uniq.reverse
    @scores.each do |user_box_score|
      user_box_score.update(rank: sorted_points.index(user_box_score.points) + 1)
    end
  end
end

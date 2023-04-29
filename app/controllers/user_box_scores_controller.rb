class UserBoxScoresController < ApplicationController
  def index
    @scores = UserBoxScore.all
    @scores = @scores.sort { |a, b| b.points <=> a.points }
    points_array = @scores.map {|user_box_score| user_box_score.points}
    sorted = points_array.sort.uniq.reverse
    points_ranks = points_array.map{ |e| sorted.index(e) + 1 }
    @scores.each_with_index do |user_box_score, index|
      user_box_score.update(rank: points_ranks[index])
    end
  end
end

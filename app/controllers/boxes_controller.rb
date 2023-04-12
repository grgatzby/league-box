class BoxesController < ApplicationController
  skip_before_action :authenticate_user!, only: :index
  def index
    # club = current_user.club
    round = Round.current.last
    @boxes = round.boxes.sort
  end

  def show
    @box = Box.find(params[:id])
    @user_matches = []
    @box.user_box_scores.each do |user_box_score|
      opponent_matches = matches(user_box_score.user)
      current_user_matches = matches(current_user)
      match_played = (opponent_matches & current_user_matches)[0]
      @user_matches << [user_box_score, match_played]
    end
  end

  private

  def matches(user)
    user.user_match_scores.select { |user_match_score| user_match_score.match.box == @box }.map(&:match)
  end
end

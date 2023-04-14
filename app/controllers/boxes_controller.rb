class BoxesController < ApplicationController
  skip_before_action :authenticate_user!, only: :index
  def index
    round = Round.current.last
    @boxes = round.boxes.sort
  end

  def show
    @box = Box.find(params[:id])
    # array of [user_box_score , matches(user_box_score.user)]
    #  where : matches(user_box_score.user) = array of [match, opponent, user_score, opponent_score]
    @box_matches = box_matches_list(@box)
  end

  def mybox
    @box = Box.find(params[:id])
    @user_matches = []
    @box.user_box_scores.each do |user_box_score|
      opponent_matches = matches(user_box_score.user)
      current_user_matches = matches(current_user)
      match_played = (opponent_matches & current_user_matches)[0]
      @user_matches << [user_box_score, match_played]
    end
    @user_matches
  end

  private

  def matches(user)
    user.user_match_scores.select { |user_match_score| user_match_score.match.box == @box }.map(&:match)
  end

  def matches_details(user)
    matches = matches(user)
    matches.map do |match|
      opponent = opponent(match, user)
      [match, opponent, match_score(match, user), match_score(match, opponent)]
    end
  end

  def opponent(match, player)
    match.user_match_scores.reject { |user_match_score| user_match_score.user == player }.map(&:user)[0]
  end

  def box_matches_list(box)
    box_matches_list = []
    box.user_box_scores.each do |user_box_score|
      box_matches_list << [user_box_score, matches_details(user_box_score.user)]
    end
    box_matches_list.sort { |a, b| b[0].points <=> a[0].points }
  end

  def match_score(match, player)
    match.user_match_scores.select { |element| element.user == player }[0]
  end
end

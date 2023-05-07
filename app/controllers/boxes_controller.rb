class BoxesController < ApplicationController
  # skip_before_action :authenticate_user!, only: :index
  def index
    set_club_and_round
  end

  def show
    @box = Box.find(params[:id])
    # @box_matches: array of [user_box_score , matches(user_box_score.user)]
    # matches(user_box_score.user): array of [match, opponent, user_score, opponent_score]
    @box_matches = box_matches(@box)
  end

  def show_list
    show
  end

  def show_manager
    show
  end

  def mybox
    @box = Box.find(params[:id])
    @user_matches = []
    @box.user_box_scores.each do |user_box_score|
      opponent_matches = user_matches(user_box_score.user, @box)
      current_user_matches = user_matches(current_user, @box)
      match_played = (opponent_matches & current_user_matches)[0]
      @user_matches << [user_box_score, match_played]
    end
    @user_matches = @user_matches.sort { |a, b| b[0].points <=> a[0].points }
  end

  private

  def user_matches(user, box)
    # for given user, select match scores in box, and return array of matches
    user.user_match_scores.select { |user_match_score| user_match_score.match.box == box }.map(&:match)
  end

  def opponent(match, player)
    # for given match select match score of other player, and return other player
    match.user_match_scores.reject { |user_match_score| user_match_score.user == player }.map(&:user)[0]
  end

  def box_matches(box)
    # return array of [user_box_score, matches_details, user] sorted by player's total points
    box_matches = []
    box.user_box_scores.each do |user_box_score|
      box_matches << [user_box_score, matches_details(user_box_score), user_box_score.user]
    end
    # sort by descending points scores
    box_matches.sort { |a, b| b[0].points <=> a[0].points }
  end

  def matches_details(user_box_score)
    user = user_box_score.user
    matches = user_matches(user, user_box_score.box)
    matches.map! do |match|
      opponent = opponent(match, user)
      [match, opponent, match_score(match, user), match_score(match, opponent)]
    end
    # add user to list
    matches << [nil, user, nil, nil]
  end

  def match_score(match, player)
    match.user_match_scores.select { |x| x.user == player }[0]
  end
end

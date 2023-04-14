class MatchesController < ApplicationController
  def show
    @opponent = User.find(params[:user_id])
    @match = Match.find(params[:match_id])
    @current_user_match_score = match_score(@match, current_user)
    @opponent_match_score = match_score(@match, @opponent)
  end

  def new
    @opponent = User.find(params[:user_id])
    @match = Match.new
  end

  def create
    # create a new Match instance with the form input and a UserMatchScore instance for each player
    @match = Match.new
    @match.box = current_user.user_box_scores[0].box
    @match.court = Court.find_by name: params[:match][:court_id]
    @match.save
    UserMatchScore.create(user_id: current_user.id, match_id: @match.id)
    UserMatchScore.create(user_id: params[:user_id], match_id: @match.id)
    redirect_to match_user_match_scores_path(match_id: @match.id)
  end

  private

  def match_score(match, player)
    match.user_match_scores.select { |element| element.user == player }[0]
  end
end

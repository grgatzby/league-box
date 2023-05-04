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
    # creates a new Match instance with the matches/new.html.erb form and creates one UserMatchScore instance for each player
    @match = Match.new
    @match.box = current_user.user_box_scores[0].box
    # finds the court from the input court number
    @match.court = Court.find_by name: params[:match][:court_id]
    @match.save
    # creates the two match scores for the match
    UserMatchScore.create(user_id: current_user.id, match_id: @match.id)
    UserMatchScore.create(user_id: params[:user_id], match_id: @match.id)
    # redirects to the scores input form in user_match_scores/new.html.erb
    redirect_to match_user_match_scores_path(match_id: @match.id)
  end

  def destroy
    @match = Match.find(params[:id])
    user_match_scores = UserMatchScore.where(match_id: @match.id)
    # update points in user_box_score for each player
    [0, 1].each do |index|
      user_box_score = UserBoxScore.find_by(box_id: @match.box_id, user_id: user_match_scores[index].user_id)
      user_box_score.points -= user_match_scores[index].points
      user_box_score.save
    end
    @match.destroy
    # display league table
    redirect_to user_box_scores_path
  end

  private

  def match_score(match, player)
    match.user_match_scores.select { |user_match_score| user_match_score.user == player }[0]
  end
end

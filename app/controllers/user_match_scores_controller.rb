class UserMatchScoresController < ApplicationController
  def match_NO_LONGER_USED
    @user_match_scores = UserMatchScore.where(match_id: params[:match_id])
    @match = Match.find(params[:match_id])
  end

  def edit_both
    # manager: edit match scores
    # calls form UserMatchScore / edit_both.html.erb
    @user_match_scores = UserMatchScore.where(match_id: params[:match_id])
    if @user_match_scores[0].score_tiebreak.zero? && @user_match_scores[1].score_tiebreak.zero?
      @user_match_scores[0].score_tiebreak = "Na"
      @user_match_scores[1].score_tiebreak = "Na"
    end
    @match = Match.find(params[:match_id])
  end

  def update
    # called by form in UserMatchScore / edit_both.html.erb
    user_match_scores = UserMatchScore.where(match_id: params[:match_id])

    results = compute_results(user_match_scores)
    # stores current match points for each player
    match_points = [{}, {}]
    [0, 1].each do |index|
      match_points[index][:points] = user_match_scores[index].points
      match_points[index][:sets_won] = results[index]
      match_points[index][:sets_played] = results.sum
      match_points[index][:games_won] = results[index] > results[1 - index] ? 1 : 0
    end

    # updates match scores for each player
    id = user_match_scores[0].id.to_s
    user_match_scores[0].score_set1 = params[:user_match_scores][id][:score_set1].to_i
    user_match_scores[0].score_set2 = params[:user_match_scores][id][:score_set2].to_i
    user_match_scores[0].score_tiebreak = params[:user_match_scores][id][:score_tiebreak].to_i

    id = user_match_scores[1].id.to_s
    user_match_scores[1].score_set1 = params[:user_match_scores][id][:score_set1].to_i
    user_match_scores[1].score_set2 = params[:user_match_scores][id][:score_set2].to_i
    user_match_scores[1].score_tiebreak = params[:user_match_scores][id][:score_tiebreak].to_i

    # updates points in user_match_scores and return winner/loser hash (count of sets won)
    results = compute_points(user_match_scores)

    if test_scores(user_match_scores, results)

      # if score entered is valid update winner and loser booleans in user_match_scores
      user_match_scores[0].is_winner = (results[0] > results[1])
      user_match_scores[1].is_winner = (results[1] > results[0])

      user_match_scores[0].save
      user_match_scores[1].save
      # updates user_box_score for each player
      [0, 1].each do |index|
        match = user_match_scores[index].match
        user_box_score = UserBoxScore.find_by(box_id: match.box_id, user_id: user_match_scores[index].user_id)
        user_box_score.points += user_match_scores[index].points - match_points[index][:points]
        user_box_score.sets_won += results[index] - match_points[index][:sets_won]
        user_box_score.sets_played += results.sum - match_points[index][:sets_played]
        user_box_score.games_won += (results[index] > results[1 - index] ? 1 : 0) - match_points[index][:games_won]
        # user_box_score.games_played is unchanged
        user_box_score.save
        @round = match.box.round
      end
      # displays league table
      # redirect_to user_box_scores_path(round_start: @round.start_date)
      redirect_to user_box_scores_path(round_start: @round.start_date, club_name: @round.club.name)
    else
      # if score entered is not valid
      redirect_back(fallback_location: match_user_match_scores_path)
    end
  end

  private

  def user_match_score_params
    params.require(:user_match_score).permit([:score_set1, :score_set2, :score_tiebreak, :points, :is_winner])
  end
end

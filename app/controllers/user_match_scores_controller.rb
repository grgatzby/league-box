class UserMatchScoresController < ApplicationController
  def match
    @user_match_scores = UserMatchScore.where(match_id: params[:match_id])
    @match = Match.find(params[:match_id])
  end

  def edit_both
    @user_match_scores = UserMatchScore.where(match_id: params[:match_id])
    if (@user_match_scores[0].score_tiebreak == 0 && @user_match_scores[1].score_tiebreak == 0)
      @user_match_scores[0].score_tiebreak = "Na"
      @user_match_scores[1].score_tiebreak = "Na"
    end
    @match = Match.find(params[:match_id])
  end

  def update
    user_match_scores = UserMatchScore.where(match_id: params[:match_id])

    # update match scores for each player
    id = user_match_scores[0].id.to_s
    user_match_scores[0].score_set1 = params[:user_match_scores][id][:score_set1].to_i
    user_match_scores[0].score_set2 = params[:user_match_scores][id][:score_set2].to_i
    user_match_scores[0].score_tiebreak = params[:user_match_scores][id][:score_tiebreak].to_i

    id = user_match_scores[1].id.to_s
    user_match_scores[1].score_set1 = params[:user_match_scores][id][:score_set1].to_i
    user_match_scores[1].score_set2 = params[:user_match_scores][id][:score_set2].to_i
    user_match_scores[1].score_tiebreak = params[:user_match_scores][id][:score_tiebreak].to_i

    # store previous match points for each player
    match_points = []
    [0, 1].each do |index|
      match_points[index] = user_match_scores[index].points
    end
    # update points in user_match_scores and return winner/loser array (count of sets won)
    winner = compute_points(user_match_scores)

    if test_scores(user_match_scores, winner)
      # if score entered is valid update winner and loser in user_match_scores
      user_match_scores[0].is_winner = (winner[0] == 2)
      user_match_scores[1].is_winner = (winner[1] == 2)

      user_match_scores[0].save
      user_match_scores[1].save
      # update points in user_box_score for each player
      [0, 1].each do |index|
        match = user_match_scores[index].match
        user_box_score = UserBoxScore.find_by(box_id: match.box_id, user_id: user_match_scores[index].user_id)
        user_box_score.points += user_match_scores[index].points - match_points[index]
        user_box_score.save
      end
      # display league table
      redirect_to user_box_scores_path
    else
      # score entered is not valid
      redirect_back(fallback_location: match_user_match_scores_path)
    end
  end

  def scores
    # computes the form from user_match_score/match.html.erb
    # once match is played, updates user_match_score and user_box_score for both players
    user_match_scores = UserMatchScore.where(match_id: params[:match_id])
    user_match_scores[0].user_id = params[:player1_id].to_i
    user_match_scores[0].score_set1 = params[:score1_set1].to_i
    user_match_scores[0].score_set2 = params[:score1_set2].to_i
    user_match_scores[0].score_tiebreak = params[:score1_tiebreak].to_i

    user_match_scores[1].user_id = params[:player2_id].to_i
    user_match_scores[1].score_set1 = params[:score2_set1].to_i
    user_match_scores[1].score_set2 = params[:score2_set2].to_i
    user_match_scores[1].score_tiebreak = params[:score2_tiebreak].to_i

    # update points in user_match_scores and return winner/loser array (count of sets won)
    winner = compute_points(user_match_scores)

    if test_scores(user_match_scores, winner)
      #  if score entered is valid, store match date and time
      match = Match.find(params[:match_id])
      match.time = "#{params[:date]} #{params['time(4i)']}:#{params['time(5i)']}:00".to_datetime
      match.save

      # update winner and loser in user_match_scores
      user_match_scores[0].is_winner = (winner[0] == 2)
      user_match_scores[1].is_winner = (winner[1] == 2)

      user_match_scores[0].save
      user_match_scores[1].save

      # update points in user_box_score for each player
      [0, 1].each do |index|
        match = user_match_scores[index].match
        user_box_score = UserBoxScore.find_by(box_id: match.box_id, user_id: user_match_scores[index].user_id)
        user_box_score.points += user_match_scores[index].points
        user_box_score.save
      end
      redirect_to box_path(current_user.user_box_scores[0].box)
    else
      # score entered is not valid
      redirect_back(fallback_location: match_user_match_scores_path)
    end
  end

  private

  def user_match_score_params
    params.require(:user_match_score).permit([:score_set1, :score_set2, :score_tiebreak, :points, :is_winner])
  end

  def compute_points(user_match_scores)
    # Winner 20 points
    # Looser 10 points per set won + number of games per lost set
    # The championship tie-break counts as one set (no points awarded for the looser)
    winner = [0, 0]
    # first set
    if user_match_scores[0].score_set1 > user_match_scores[1].score_set1
      winner[0] += 1
      user_match_scores[0].points = 10
      user_match_scores[1].points = user_match_scores[1].score_set1
    else
      winner[1] += 1
      user_match_scores[0].points = user_match_scores[0].score_set1
      user_match_scores[1].points = 10
    end

    # second set
    if user_match_scores[0].score_set2 > user_match_scores[1].score_set2
      winner[0] += 1
      user_match_scores[0].points += 10
      user_match_scores[1].points += user_match_scores[1].score_set2
    else
      winner[1] += 1
      user_match_scores[0].points += user_match_scores[0].score_set2
      user_match_scores[1].points += 10
    end

    # tie break
    if winner[0] == 1 || winner[1] == 1
      if user_match_scores[0].score_tiebreak > user_match_scores[1].score_tiebreak
        winner[0] += 1
        user_match_scores[0].points = 20
      else
        winner[1] += 1
        user_match_scores[1].points = 20
      end
    else
      user_match_scores[0].score_tiebreak = 0
      user_match_scores[1].score_tiebreak = 0
    end
    # return winner array (count of sets won)
    winner
  end

  def test_scores(user_match_scores, winner)
    if (user_match_scores[0].score_set1 < 4 && user_match_scores[1].score_set1 < 4) ||
       (user_match_scores[0].score_set2 < 4 && user_match_scores[1].score_set2 < 4)
       raise
       flash[:alert] = "One score must be 4 for set 1 and set 2."
      false
    elsif (user_match_scores[0].score_set1 == 4 && user_match_scores[1].score_set1 == 4) ||
          (user_match_scores[0].score_set2 == 4 && user_match_scores[1].score_set2 == 4)
      flash[:alert] = "4-4 is not a valid score."
      false
    elsif (user_match_scores[0].score_tiebreak < 10 && user_match_scores[1].score_tiebreak < 10) &&
          (winner[0] == 1 || winner[1] == 1)
      flash[:alert] = "One tiebreak score must be at least 10."
      false
    elsif ((user_match_scores[0].score_tiebreak > 10 && user_match_scores[1].score_tiebreak < 9) ||
          (user_match_scores[0].score_tiebreak < 9 && user_match_scores[1].score_tiebreak > 10)) &&
          (winner[0] == 1 || winner[1] == 1)
      flash[:alert] = "One tiebreak score must be 10."
      false
    elsif (user_match_scores[0].score_tiebreak - user_match_scores[1].score_tiebreak).abs < 2 &&
          (winner[0] == 1 || winner[1] == 1)
      flash[:alert] = "Tiebreak score must be 2 clear."
      false
    else
      true
    end
  end
end

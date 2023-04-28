class UserMatchScoresController < ApplicationController
  def match
    @user_match_scores = UserMatchScore.where(match_id: params[:match_id])
    @match = Match.find(params[:match_id])
  end

  def scores
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

    # Winner 20 points
    # Looser 10 points per set won + number of games per lost set
    # The championship tie-break counts as one set (no points awarded for the looser)
    winner0 = 0
    winner1 = 0
    # first set
    if user_match_scores[0].score_set1 > user_match_scores[1].score_set1
      winner0 += 1
      user_match_scores[0].points = 10
      user_match_scores[1].points = user_match_scores[1].score_set1
    else
      winner1 += 1
      user_match_scores[0].points = user_match_scores[0].score_set1
      user_match_scores[1].points = 10
    end

    # second set
    if user_match_scores[0].score_set2 > user_match_scores[1].score_set2
      winner0 += 1
      user_match_scores[0].points += 10
      user_match_scores[1].points += user_match_scores[1].score_set2
    else
      winner1 += 1
      user_match_scores[0].points += user_match_scores[0].score_set2
      user_match_scores[1].points += 10
    end

    # tie break
    if winner0 == 1 || winner1 == 1
      if user_match_scores[0].score_tiebreak > user_match_scores[1].score_tiebreak
        winner0 += 1
        user_match_scores[0].points = 20
      else
        winner1 += 1
        user_match_scores[1].points = 20
      end
    end

    # match date and time
    match = Match.find(params[:match_id])
    match.time = "#{params[:date]} #{params['time(4i)']}:#{params['time(5i)']}:00".to_datetime
    match.save

    # winner and loser
    user_match_scores[0].is_winner = (winner0 == 2)
    user_match_scores[1].is_winner = (winner1 == 2)

    user_match_scores[0].save
    user_match_scores[1].save

    # update user_box_score for each user
    [0, 1].each do |index|
      match = user_match_scores[index].match
      user_box_score = UserBoxScore.where(box_id: match.box_id, user_id: user_match_scores[index].user_id)[0]
      user_box_score.points += user_match_scores[index].points
      user_box_score.save
    end

    redirect_to box_path(current_user.user_box_scores[0].box)
  end
end

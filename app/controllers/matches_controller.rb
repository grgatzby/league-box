class MatchesController < ApplicationController
  def show
    @opponent = User.find(params[:user_id])
    @match = Match.find(params[:match_id])
    @current_user_match_score = match_score(@match, current_user)
    @opponent_match_score = match_score(@match, @opponent)
    @my_current_box = my_box(current_round(current_user))
  end

  def new
    @current_player = params[:player_id] ? User.find(params[:player_id]) : current_user
    @opponent = User.find(params[:opponent_id])
    @round = Round.find(params[:round_id])
    # max match date in the form: lowest of round end date and current date
    @end_select = [@round.end_date, Time.now].min
    @match = Match.new(time: @end_select)
    # the matches/new.html.erb form supports user_match_scores nested attributes
    @match.user_match_scores.build
    @match.user_match_scores.build
  end

  def create
    # create new Match instance with the matches/new.html.erb form and a UserMatchScore instance for each player
    @match = Match.new
    @current_player = User.find(params[:player_id])
    @match.box = my_box(Round.find(params[:round_id]), @current_player)
    # get the court from the input court number (user inputs court number in lieu of court id)
    @match.court = Court.find_by name: params[:match][:court_id]

    match_scores = [{}, {}]
    # update match scores for each player
    match_scores[0][:score_set1] = params[:match][:user_match_scores_attributes]["0"][:score_set1].to_i
    match_scores[0][:score_set2] = params[:match][:user_match_scores_attributes]["0"][:score_set2].to_i
    match_scores[0][:score_tiebreak] = params[:match][:user_match_scores_attributes]["0"][:score_tiebreak].to_i

    match_scores[1][:score_set1] = params[:match][:user_match_scores_attributes]["1"][:score_set1].to_i
    match_scores[1][:score_set2] = params[:match][:user_match_scores_attributes]["1"][:score_set2].to_i
    match_scores[1][:score_tiebreak] = params[:match][:user_match_scores_attributes]["1"][:score_tiebreak].to_i

    results = compute_points(match_scores)

    if test_scores(match_scores, results)
      # if score entered is valid, store match date and match time
      @match.time = "#{params[:match][:time]} #{params[:match]['time(4i)']}:#{params[:match]['time(5i)']}:00".to_datetime
      @match.save

      # create the two match scores for the match
      UserMatchScore.create(user_id: params[:player_id], match_id: @match.id)
      UserMatchScore.create(user_id: params[:opponent_id], match_id: @match.id)

      user_match_scores = UserMatchScore.where(match_id: @match.id)

      # update match scores and points for each player, determine winner and loser, and save user_match_scores
      user_match_scores[0].score_set1 = match_scores[0][:score_set1]
      user_match_scores[0].score_set2 = match_scores[0][:score_set2]
      user_match_scores[0].score_tiebreak = match_scores[0][:score_tiebreak]
      user_match_scores[0].points = match_scores[0][:points]

      user_match_scores[1].score_set1 = match_scores[1][:score_set1]
      user_match_scores[1].score_set2 = match_scores[1][:score_set2]
      user_match_scores[1].score_tiebreak = match_scores[1][:score_tiebreak]
      user_match_scores[1].points = match_scores[1][:points]

      user_match_scores[0].is_winner = (results[0] > results[1])
      user_match_scores[1].is_winner = (results[1] > results[0])

      input_date = Time.now
      user_match_scores[0].input_user_id = current_user.id
      user_match_scores[0].input_date = input_date
      user_match_scores[1].input_user_id = current_user.id
      user_match_scores[1].input_date = input_date

      user_match_scores[0].save
      user_match_scores[1].save

      # update user_box_score for each player
      [0, 1].each do |index|
        match = user_match_scores[index].match
        user_box_score = UserBoxScore.find_by(box_id: match.box_id, user_id: user_match_scores[index].user_id)
        user_box_score.points += user_match_scores[index].points
        user_box_score.sets_won += results[index]
        user_box_score.sets_played += results.sum
        user_box_score.games_won += results[index] > results[1 - index] ? 1 : 0
        user_box_score.games_played += 1
        user_box_score.save
      end

      # redirect to league table
      # redirect_to user_box_scores_path(round_start: params[:round_start])
      redirect_to user_box_scores_path(round_start: params[:round_start], club_name: @current_player.club.name)
    else
      # if score entered is not valid, retake the form
      redirect_back(fallback_location: new_match_path)
    end
  end

  def destroy
    # for admin and referees only
    @match = Match.find(params[:id])
    user_match_scores = UserMatchScore.where(match_id: @match.id)
    results = compute_results(user_match_scores)
    # update user_box_score for each player
    [0, 1].each do |index|
      user_box_score = UserBoxScore.find_by(box_id: @match.box_id, user_id: user_match_scores[index].user_id)

      user_box_score.points -= user_match_scores[index].points
      user_box_score.sets_won -= results[index]
      user_box_score.sets_played -= results.sum
      user_box_score.games_won -= results[index] > results[1 - index] ? 1 : 0
      user_box_score.games_played -= 1
      user_box_score.save
    end
    @match.destroy
    # redirect to league table
    # TO DO: check what round: param is expected
    redirect_to user_box_scores_path(round_start: params[:round_start])
  end

  private

  def match_score(match, player)
    match.user_match_scores.select { |user_match_score| user_match_score.user == player }[0]
  end
end

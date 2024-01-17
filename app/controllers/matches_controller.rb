class MatchesController < ApplicationController
  def show
    @page_from = local_path(params[:page_from])
    @player = User.find(params[:player])
    @opponent = User.find(params[:opponent])
    # @referee = @referee || User.find_by(role: "referee", club_id: @player.club.id)
    @referee ||= User.find_by(role: "referee", club_id: @player.club.id)
    @match = Match.find(params[:match])
    @player_match_score = match_score(@match, @player)
    @opponent_match_score = match_score(@match, @opponent)
  end

  def new
    @page_from = local_path(params[:page_from])
    @round = Round.find(params[:round])
    @current_player = params[:player] ? User.find(params[:player]) : current_user
    @box = my_own_box(@round, @current_player)
    if @round.start_date > Time.now
      flash[:notice] = t('.round_not_started_flash')
      redirect_back(fallback_location: @page_from)
    else
      @opponent = User.find(params[:opponent])
      # max match date in the form: user can't post results in the future
      @max_end_date = [@round.end_date, Time.now].min
      @match = Match.new(time: @max_end_date)
      @match.user_match_scores.build
      # if params[:score_set1]
      #   @match_entry = Match.new
      #   score_set1 = split_score(params[:score_set1])
      #   score_set2 = split_score(params[:score_set2])
      #   score_tiebreak = split_score(params[:score_tiebreak])
      #   @match_entry.user_match_scores.build
      #   @match_entry.user_match_scores.build
      #   [0, 1].each do |index|
      #     @match_entry.user_match_scores[index][:score_set1] = score_set1[index]
      #     @match_entry.user_match_scores[index][:score_set2] = score_set2[index]
      #     @match_entry.user_match_scores[index][:score_tiebreak] = score_tiebreak[index]
      #   end
      #   # raise
      # end
      # nested attributes for user_match_scores: comment out the line below allows separate input per player
      # for simplicity we now enter scores in 3 inputs rather than 6
      # @match.user_match_scores.build
    end
  end

  def create
    # create new Match instance with the matches/new.html.erb form and 2 UserMatchScore instances
    @match = Match.new
    @current_player = User.find(params[:player])
    @match.box = my_own_box(Round.find(params[:round]), @current_player)
    # get the court from the input court number (user inputs court number in lieu of court id)
    @match.court = Court.find_by name: params[:match][:court_id]

    match_scores = [{}, {}]
    score_set1 = split_score(params[:match][:user_match_scores_attributes]["0"][:score_set1])
    score_set2 = split_score(params[:match][:user_match_scores_attributes]["0"][:score_set2])
    score_tiebreak = split_score(params[:match][:user_match_scores_attributes]["0"][:score_tiebreak])
    [0, 1].each do |index|
      match_scores[index][:score_set1] = score_set1[index]
      match_scores[index][:score_set2] = score_set2[index]
      match_scores[index][:score_tiebreak] = score_tiebreak[index]
    end

    test_score = test_new_score(match_scores) # ARRAY of won sets count if scores ok, false otherwise
    if test_score
      results = compute_points(match_scores)

      # if score entered is valid, store match date and match time in UTC Time
      # @match.time = @tz.local_to_utc("#{params[:match][:time]} #{params[:match]['time(4i)']}:#{params[:match]['time(5i)']}:00".to_datetime)
      # previously, user could enter match hour in the form, but it was deemed unnecessary and not ux friendly
      @match.time = @tz.local_to_utc("#{params[:match][:time]} #12:00".to_datetime)
      @match.save

      # create the two match scores for the match
      UserMatchScore.create(user_id: params[:player], match_id: @match.id)
      UserMatchScore.create(user_id: params[:opponent], match_id: @match.id)

      user_match_scores = UserMatchScore.where(match_id: @match.id)

      input_date = Time.now
      [0, 1].each do |index|
        user_match_scores[index].score_set1 = match_scores[index][:score_set1]
        user_match_scores[index].score_set2 = match_scores[index][:score_set2]
        user_match_scores[index].score_tiebreak = match_scores[index][:score_tiebreak]
        user_match_scores[index].points = match_scores[index][:points]
        user_match_scores[index].is_winner = (results[index] > results[1 - index])
        user_match_scores[index].input_user_id = current_user.id
        user_match_scores[index].input_date = input_date
        user_match_scores[index].save
      end

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

      # update the league table
      rank_players(@match.box.round.user_box_scores)

      redirect_to local_path(params[:page_from])
    else
      # if score entered is not valid, retake the form
      more_params = {
        time: params[:match][:time],
        court_id: params[:match][:court_id],
        score_set1: params[:match][:user_match_scores_attributes]["0"][:score_set1],
        score_set2: params[:match][:user_match_scores_attributes]["0"][:score_set2],
        score_tiebreak: params[:match][:user_match_scores_attributes]["0"][:score_tiebreak]
      }
      # my aim = include new score entry to new match form, maybe not possible through redirect_back
      # redirect_back(fallback_location: new_match_path)
      redirect_to_back(more_params)
    end
  end

  def edit
    @page_from = local_path(params[:page_from])
    # for admin and referees only
    # allows to edit match scores (match and 2 user_match_scores)
    @user_match_scores = UserMatchScore.where(match_id: params[:match_id])
    if @user_match_scores[0].score_tiebreak.zero? && @user_match_scores[1].score_tiebreak.zero?
      @user_match_scores[0].score_tiebreak = "Na"
      @user_match_scores[1].score_tiebreak = "Na"
    end
    @current_player = @user_match_scores[0].user
    @opponent = @user_match_scores[1].user

    @match = Match.find(params[:match_id])
    @match.court_id = @match.court.name
    # convert @match.time from UTC time to local time for display in the form
    @match.time += @tz.to_local(@match.time).utc_offset
    @round = @match.box.round
    # max match date in the form: user can't post results in the future
    @max_end_date = [@round.end_date, Time.now].min
  end

  def update
    match = Match.find(params[:match_id])
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

    # updates match scores for each player (without saving)
    input_date = Time.now
    [0, 1].each do |index|
      user_match_scores[index].score_set1 = params[:match][:user_match_scores_attributes][index.to_s][:score_set1].to_i
      user_match_scores[index].score_set2 = params[:match][:user_match_scores_attributes][index.to_s][:score_set2].to_i
      user_match_scores[index].score_tiebreak = params[:match][:user_match_scores_attributes][index.to_s][:score_tiebreak].to_i
      user_match_scores[index].input_user_id = current_user.id
      user_match_scores[index].input_date = input_date
    end

    # updates points in user_match_scores and return winner/loser hash (count of sets won)
    results = compute_points(user_match_scores)

    if test_edit_score(user_match_scores, results)
      # if score entered is valid, store match date and match time in UTC time
      match.court_id = Court.find_by(name: params[:match][:court_id], club_id: match.court.club_id).id
      # match.time = @tz.local_to_utc("#{params[:match][:time]} #{params[:match]['time(4i)']}:#{params[:match]['time(5i)']}:00".to_datetime)
      # previously, user could enter match hour in the form, but it was deemed  unnecessary and not ux friendly
      @match.time = @tz.local_to_utc("#{params[:match][:time]} #12:00".to_datetime)
      match.save

      # if score entered is valid, update winner and loser booleans in user_match_scores
      [0, 1].each do |index|
        user_match_scores[index].is_winner = (results[index] > results[1 - index])
        user_match_scores[index].save
      end

      # updates user_box_score for each player
      [0, 1].each do |index|
        match = user_match_scores[index].match
        user_box_score = UserBoxScore.find_by(box_id: match.box_id, user_id: user_match_scores[index].user_id)
        user_box_score.points += user_match_scores[index].points - match_points[index][:points]
        user_box_score.sets_won += results[index] - match_points[index][:sets_won]
        user_box_score.sets_played += results.sum - match_points[index][:sets_played]
        user_box_score.games_won += (results[index] > results[1 - index] ? 1 : 0) - match_points[index][:games_won]
        # user_box_score.games_played is unchanged: no need to update
        user_box_score.save
        @round = match.box.round
      end

      # update the league table
      rank_players(match.box.round.user_box_scores)
      redirect_to local_path(params[:page_from])
    else
      # if score entered is not valid
      redirect_back(fallback_location: edit_match_path)
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

    # update the league table
    rank_players(@match.box.round.user_box_scores)
    redirect_to local_path(params[:page_from])
  end

  private

  def compute_points(match_scores)
    # compute match_scores (array of 2 hashes of scores),
    # and returns results (array of won sets count for each player)
    # Points rules:
    #   - Winner 20 points
    #   - Looser 10 points per set won + number of games per lost set
    #   - The championship tie-break counts as one set (no points awarded for the looser)

    results = compute_results(match_scores)
    # first set
    if match_scores[0][:score_set1] > match_scores[1][:score_set1]
      match_scores[0][:points] = 10
      match_scores[1][:points] = match_scores[1][:score_set1]
    else
      match_scores[0][:points] = match_scores[0][:score_set1]
      match_scores[1][:points] = 10
    end

    # second set
    if match_scores[0][:score_set2] > match_scores[1][:score_set2]
      match_scores[0][:points] += 10
      match_scores[1][:points] += match_scores[1][:score_set2]
    else
      match_scores[0][:points] += match_scores[0][:score_set2]
      match_scores[1][:points] += 10
    end

    # championship tie break
    if results[0] == 1 || results[1] == 1
      if match_scores[0][:score_tiebreak] > match_scores[1][:score_tiebreak]
        match_scores[0][:points] = 20
      else
        match_scores[1][:points] = 20
      end
    else
      match_scores[0][:score_tiebreak] = 0
      match_scores[1][:score_tiebreak] = 0
    end
    # return results (ARRAY of won sets count for each player)
    results
  end

  def compute_results(match_scores)
    # compute and returns results (array of won sets count for each player)

    results = { sets_won1: 0, sets_won2: 0 }

    # first set
    if match_scores[0][:score_set1] > match_scores[1][:score_set1]
      results[:sets_won1] += 1
    else
      results[:sets_won2] += 1
    end

    # second set
    if match_scores[0][:score_set2] > match_scores[1][:score_set2]
      results[:sets_won1] += 1
    else
      results[:sets_won2] += 1
    end

    # championship tie break
    if results[:sets_won1] == 1 || results[:sets_won2] == 1
      if match_scores[0][:score_tiebreak] > match_scores[1][:score_tiebreak]
        results[:sets_won1] += 1
      else
        results[:sets_won2] += 1
      end
    end
    # return results (ARRAY of won sets count for each player)
    [results[:sets_won1], results[:sets_won2]]
  end

  def test_new_score(match_scores)
    # return ARRAY of won sets count for each player if scores entered in matches/new are valid,
    # returns false otherwise
    results = { sets_won1: 0, sets_won2: 0 }
    # test scores entries for first set and second set
    if (match_scores[0][:score_set1].zero? && match_scores[1][:score_set1].zero?) ||
       (match_scores[0][:score_set2].zero? && match_scores[1][:score_set2].zero?) # no score entered for either set 1 or set 2
      flash[:alert] = t('.test_scores01_flash')
      false
    else # score entries are ok for set 1 and set 2 => count won sets for each player
      # first set
      if match_scores[0][:score_set1] == 4 && match_scores[1][:score_set1] < 4
        results[:sets_won1] += 1
      else
        results[:sets_won2] += 1
      end
      # second set
      if match_scores[0][:score_set2] == 4 && match_scores[1][:score_set2] < 4
        results[:sets_won1] += 1
      else
        results[:sets_won2] += 1
      end

      # test score entries for the tiebreak
      if match_scores[0][:score_tiebreak].zero? && match_scores[1][:score_tiebreak].zero? &&
         (results[:sets_won1] == 1 || results[:sets_won2] == 1) # no score entered for the tiebreak with 1 set each
        flash[:alert] = t('.test_scores02_flash')
        false
      elsif (match_scores[0][:score_tiebreak] > 0 || match_scores[1][:score_tiebreak] > 0) &&
            (results[:sets_won1] == 2 || results[:sets_won2] == 2) # unnecessary tiebreak score entered
        flash[:notice] = t('.test_scores03_flash')
        true # return a notice but enter the score without the tiebreak score
      else
        if match_scores[0][:score_tiebreak] == 4
          results[:sets_won1] += 1
        else
          results[:sets_won2] += 1
        end
        # return results (ARRAY of won sets count for each player)
        [results[:sets_won1], results[:sets_won2]]
      end
    end
  end

  def test_edit_score(match_scores, results)
    # return true if scores entered in matches/edit are valid, false otherwise
    if (match_scores[0][:score_set1] < 4 && match_scores[1][:score_set1] < 4) ||
       (match_scores[0][:score_set2] < 4 && match_scores[1][:score_set2] < 4)
      flash[:alert] = t('.test_scores01_flash')
      false
    elsif (match_scores[0][:score_set1] == 4 && match_scores[1][:score_set1] == 4) ||
          (match_scores[0][:score_set2] == 4 && match_scores[1][:score_set2] == 4)
      flash[:alert] = t('.test_scores02_flash')
      false
    elsif (match_scores[0][:score_tiebreak] < 10 && match_scores[1][:score_tiebreak] < 10) &&
          (results[0] == 1 || results[1] == 1)
      flash[:alert] = t('.test_scores03_flash')
      false
    elsif ((match_scores[0][:score_tiebreak] > 10 && match_scores[1][:score_tiebreak] < 9) ||
          (match_scores[0][:score_tiebreak] < 9 && match_scores[1][:score_tiebreak] > 10)) &&
          (results[0] == 1 || results[1] == 1)
      flash[:alert] = t('.test_scores04_flash')
      false
    elsif (match_scores[0][:score_tiebreak] - match_scores[1][:score_tiebreak]).abs < 2 &&
          (results[0] == 1 || results[1] == 1)
      flash[:alert] = t('.test_scores05_flash')
      false
    else
      true
    end
  end

  def split_score(score)
    [score.match(/.+?(?=-)/).to_s.to_i, score.split("-")[-1].to_i]
  end
end

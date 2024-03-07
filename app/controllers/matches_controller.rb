class MatchesController < ApplicationController
  REQUIRED_SCORE_HEADERS = ["first_name_player", "last_name_player",
                            "first_name_opponent", "last_name_opponent",
                            "points_player", "points_opponent",
                            "box_number", "score_winner", "score_winner2"]
  REQUIRED_SCORE_HEADERS_PLUS = ["email_player", "phone_number_player", "role_player",
                                 "email_opponent", "phone_number_opponent", "role_opponent"]
  SHORT_TIEBREAK_EDIT = 7 #although the tie-break rule is first to 10, admin/referee may edit score and allow first to 7

  def show
    @page_from = local_path(params[:page_from])
    @player = User.find(params[:player])
    @opponent = User.find(params[:opponent])
    # @referee = @referee || User.find_by(role: "referee", club_id: @player.club.id)
    # @referee ||= User.find_by(role: "referee", club_id: @player.club.id) #TO DO : role includes referee
    @referee ||= User.find_by("club_id = ? AND role like ?", @player.club.id, "%referee%")
    @match = Match.find(params[:match_id])
    @player_match_score = match_score(@match, @player)
    @opponent_match_score = match_score(@match, @opponent)
  end

  def new
    @page_from = local_path(params[:page_from])
    @round = Round.find(params[:round_id])
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
      # the code below was adapted to the previous form where scores were input individually
      # if params[:score_set1]
      #   @match_entry = Match.new
      #   score_set1 = score_to_a(params[:score_set1])
      #   score_set2 = score_to_a(params[:score_set2])
      #   score_tiebreak = score_to_a(params[:score_tiebreak])
      #   @match_entry.user_match_scores.build
      #   @match_entry.user_match_scores.build
      #   [0, 1].each do |index|
      #     @match_entry.user_match_scores[index][:score_set1] = score_set1[index]
      #     @match_entry.user_match_scores[index][:score_set2] = score_set2[index]
      #     @match_entry.user_match_scores[index][:score_tiebreak] = score_tiebreak[index]
      #   end
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
    @match.box = my_own_box(Round.find(params[:round_id]), @current_player)
    # get the court from the input court number (user inputs court number in lieu of court id)
    @match.court = Court.find_by name: params[:match][:court_id]

    match_scores = [{}, {}]
    # eg: 4-2 1-3 10-7 => [{score_set1: 4, score_set2: 1, score_tiebreak: 10}, {score_set1: 2, score_set2: 3, score_tiebreak: 7}]
    score_set1 = score_to_a(params[:match][:user_match_scores_attributes]["0"][:score_set1])
    score_set2 = score_to_a(params[:match][:user_match_scores_attributes]["0"][:score_set2])
    score_tiebreak = score_to_a(params[:match][:user_match_scores_attributes]["0"][:score_tiebreak])
    [0, 1].each do |index|
      match_scores[index][:score_set1] = score_set1[index]
      match_scores[index][:score_set2] = score_set2[index]
      match_scores[index][:score_tiebreak] = score_tiebreak[index] || 0
    end

    test_score = test_new_score(match_scores) # ARRAY of won sets count if scores ok, false otherwise
    if test_score
      results = compute_points(match_scores)
      # if score is valid, store match date and match time in UTC Time
      # @match.time = @tz.local_to_utc("#{params[:match][:time]} #{params[:match_id]['time(4i)']}:#{params[:match_id]['time(5i)']}:00".to_datetime)
      # previously, user could enter match hour in the form, but it was considered unnecessary and not ux friendly
      @match.time = @tz.local_to_utc("#{params[:match][:time]} #12:00".to_datetime)
      @match.save

      # create and fill a user_match_score instance for each player of the match
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
        user_box_score.games_won += won_games(user_match_scores[index])
        user_box_score.games_played += won_games(user_match_scores[index]) + won_games(user_match_scores[1 - index])
        user_box_score.sets_won += results[index]
        user_box_score.sets_played += results.sum
        user_box_score.matches_won += results[index] > results[1 - index] ? 1 : 0
        user_box_score.matches_played += 1
        user_box_score.save
      end

      # update the league table
      rank_players(@match.box.round.user_box_scores)

      redirect_to local_path(params[:page_from])
    else
      # if score entered is not valid, retake the form
      # redirect_back(fallback_location: new_match_path)

      # keep and display the invalid entries to the resubmitted new match form (not possible with redirect_back)
      more_params = {
        time: params[:match][:time],
        court_id: params[:match][:court_id],
        score_set1: params[:match][:user_match_scores_attributes]["0"][:score_set1],
        score_set2: params[:match][:user_match_scores_attributes]["0"][:score_set2],
        score_tiebreak: params[:match][:user_match_scores_attributes]["0"][:score_tiebreak]
      }
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

    results = compute_results(user_match_scores) # ARRAY of won sets count for each player
    # stores current match points for each player
    match_points = [{}, {}]
    [0, 1].each do |index|
      match_points[index][:points] = user_match_scores[index].points
      match_points[index][:games_won] = won_games(user_match_scores[index])
      match_points[index][:games_played] = won_games(user_match_scores[index]) + won_games(user_match_scores[1 - index])
      match_points[index][:sets_won] = results[index]
      match_points[index][:sets_played] = results.sum
      match_points[index][:matches_won] = results[index] > results[1 - index] ? 1 : 0
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

    # updates points in user_match_scores and return ARRAY of won sets count for each player
    test_edit_score = test_edit_score(user_match_scores, results)

    if test_edit_score
      results = compute_points(user_match_scores)
      # if score entered is valid, store match date and match time in UTC time
      match.court_id = Court.find_by(name: params[:match][:court_id], club_id: match.court.club_id).id
      # match.time = @tz.local_to_utc("#{params[:match][:time]} #{params[:match]['time(4i)']}:#{params[:match]['time(5i)']}:00".to_datetime)
      # previously, user could enter match hour in the form, but it was deemed  unnecessary and not ux friendly
      match.time = @tz.local_to_utc("#{params[:match][:time]} #12:00".to_datetime)
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
        user_box_score.games_won += won_games(user_match_scores[index]) - match_points[index][:games_won]
        user_box_score.games_played += won_games(user_match_scores[index]) + won_games(user_match_scores[1 - index]) - match_points[index][:games_played]
        user_box_score.matches_won += (results[index] > results[1 - index] ? 1 : 0) - match_points[index][:matches_won]
        # user_box_score.matches_played unchanged: no need to update
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
    destroy_match(@match)
    redirect_to local_path(params[:page_from])
  end

  def load_scores
  end

  def create_scores
    # populate match_scores for a chosen club and round from a CSV file
    # if players don't exist in the database, create them

    csv_file = params[:csv_file]
    delimiter = params[:delimiter]
    round = Round.find(params[:round_id])
    # 1/ remove existing scores for the round and clean user_box_score values
    Box.where(round_id: round.id).each do |box|
      box.matches.each do |match|
        destroy_match(match)
      end
    end
    # 2/ read CSV scores file
    court_id = Court.find_by(club_id: round.club_id, name: "1").id
    if csv_file.content_type == "text/csv"
      # user_box_scores are already created with users loading the round create CSV file
      # a CSV file is attached, create user_match_scores and matches using it, and populate user_box_scores records
      headers = CSV.foreach(csv_file, col_sep: delimiter).first
      if headers.compact.map(&:downcase).sort - ["id"] == (REQUIRED_SCORE_HEADERS + REQUIRED_SCORE_HEADERS_PLUS).sort
        # create and fill user_match_scores and matches
        input_date = Time.now
        user_match_scores = []
        CSV.foreach(csv_file, headers: :first_row, header_converters: :symbol, col_sep: delimiter) do |row|
          match_players = player_opponent(row)
          player = match_players[0]
          opponent = match_players[1]
          box_id = Box.find_by(box_number: row[:box_number], round_id: round.id).id

          # eg: 4-2 1-3 10-7 => [{score_set1: 4, score_set2: 1, score_tiebreak: 10}, {score_set1: 2, score_set2: 3, score_tiebreak: 7}]
          match_scores = match_scores_to_a(row[:score_winner])
          # create matches
          # if (row[:last_name_player] == "Clark" && row[:last_name_opponent] == "Whittle") ||
          #   (row[:last_name_player] == "Mardinian" && row[:last_name_opponent] == "Sevaux")
          #   raise
          # end
          test_score = test_new_score(match_scores) # ARRAY of won sets count if scores ok, false otherwise
          if test_score
            @match = Match.create(box_id:, court_id:, time: round.start_date)
            results = compute_points(match_scores)

            # create and fill a user_match_score instance for each player of the match
            UserMatchScore.create(user_id: player.id, match_id: @match.id)
            UserMatchScore.create(user_id: opponent.id, match_id: @match.id)

            # user_match_scores = UserMatchScore.where(match_id: @match.id)
            user_match_scores = @match.user_match_scores

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
              user_box_score.games_won += won_games(user_match_scores[index])
              user_box_score.games_played += won_games(user_match_scores[index]) + won_games(user_match_scores[1 - index])
              user_box_score.sets_won += results[index]
              user_box_score.sets_played += results.sum
              user_box_score.matches_won += results[index] > results[1 - index] ? 1 : 0
              user_box_score.matches_played += 1
              user_box_score.save
            end

            # update the league table
            rank_players(@match.box.round.user_box_scores) # compute user_box_scores
          end
        end
      else
        flash[:notice] = t('.header_flash')
        redirect_back(fallback_location: load_scores_path)
      end
    end
    redirect_to user_box_scores_path(round_id: round.id, club_id: round.club_id)
  end

  private

  def destroy_match(match)
    user_match_scores = UserMatchScore.where(match_id: match.id)
    results = compute_results(user_match_scores)
    # update user_box_score for each player
    [0, 1].each do |index|
      user_box_score = UserBoxScore.find_by(box_id: match.box_id, user_id: user_match_scores[index].user_id)

      user_box_score.points -= user_match_scores[index].points
      user_box_score.sets_won -= results[index]
      user_box_score.sets_played -= results.sum
      user_box_score.games_won -= won_games(user_match_scores[index])
      user_box_score.games_played -= won_games(user_match_scores[index]) + won_games(user_match_scores[1 - index])
      user_box_score.matches_won -= results[index] > results[1 - index] ? 1 : 0
      user_box_score.matches_played -= 1
      user_box_score.save
    end
    match.destroy

    # update the league table
    rank_players(match.box.round.user_box_scores)
  end

  def test_edit_score(match_scores, results)
    # for a score edit
    # return true if scores entered in matches/edit are valid, false otherwise
    # return match_scores (array of 2 hashes of scores)
    # eg: 4-2 1-3 10-7
    #     => [ {score_set1: 4, score_set2: 1, score_tiebreak: 10},
    #          {score_set1: 2, score_set2: 3, score_tiebreak: 7} ]
    if (match_scores[0][:score_set1] < 4 && match_scores[1][:score_set1] < 4) ||
       (match_scores[0][:score_set2] < 4 && match_scores[1][:score_set2] < 4)
      flash[:alert] = t('.test_scores01_flash') # A score must be entered for each set.
      false
    elsif (match_scores[0][:score_tiebreak] < SHORT_TIEBREAK_EDIT && match_scores[1][:score_tiebreak] < SHORT_TIEBREAK_EDIT) &&
          (results[0] == 1 || results[1] == 1) # no score entered for the tiebreak with 1 set each
      flash[:alert] = t('.test_scores02_flash') # There must be a winner for the tiebreak.
      false
    elsif (match_scores[0][:score_set1] == 4 && match_scores[1][:score_set1] == 4) ||
          (match_scores[0][:score_set2] == 4 && match_scores[1][:score_set2] == 4)
      flash[:alert] = t('.test_scores03_flash') # 4-4: enter a correct score for set 1 and set 2
      false
    elsif ((match_scores[0][:score_tiebreak] - match_scores[1][:score_tiebreak]).abs < 2) &&
          (results[0] == 1 || results[1] == 1)
      flash[:alert] = t('.test_scores04_flash') # Tiebreak: need 2 points clear.
      false
    elsif (match_scores[0][:score_tiebreak].positive? || match_scores[1][:score_tiebreak].positive?) &&
          (results[0] == 0 || results[1] == 0)
      flash[:notice] = t('.test_scores05_flash') # No tiebreak needed if 2 sets to love.
      true # true: return a notice but enter the score without the tiebreak score
    else
      true
    end
  end

  def compute_points(match_scores)
    # match_scores (array of 2 hashes of scores) => results (array of won sets count for each player)
    # eg: for 4-2 1-3 10-7
    #     [ {score_set1: 4, score_set2: 1, score_tiebreak: 10},
    #       {score_set1: 2, score_set2: 3, score_tiebreak: 7} ]
    # =>  [ 2 , 1 ] & transforms entry array:
    #     [ {score_set1: 4, score_set2: 1, score_tiebreak: 10, points: 20 },
    #       {score_set1: 2, score_set2: 3, score_tiebreak: 7, points: 12} ]
    # Points rules:
    #   - Winner earns 20 points
    #   - Looser earns 10 points per set won + number of games per lost set
    #   - The championship tie-break counts as one set (no points awarded for the looser)

    results = compute_results(match_scores)
    # first set
    if match_scores[0][:score_set1] > match_scores[1][:score_set1]
      match_scores[0][:points] = 10
      match_scores[1][:points] = match_scores[1][:score_set1]
    elsif match_scores[0][:score_set1] < match_scores[1][:score_set1]
      match_scores[0][:points] = match_scores[0][:score_set1]
      match_scores[1][:points] = 10
    end

    # second set
    if match_scores[0][:score_set2] > match_scores[1][:score_set2]
      match_scores[0][:points] += 10
      match_scores[1][:points] += match_scores[1][:score_set2]
    elsif match_scores[0][:score_set2] < match_scores[1][:score_set2]
      match_scores[0][:points] += match_scores[0][:score_set2]
      match_scores[1][:points] += 10
    end

    # championship tie break
    if results[0] == 1 || results[1] == 1
      if match_scores[0][:score_tiebreak] > match_scores[1][:score_tiebreak]
        match_scores[0][:points] = 20
      elsif match_scores[0][:score_tiebreak] < match_scores[1][:score_tiebreak]
        match_scores[1][:points] = 20
      end
    else
      match_scores[0][:score_tiebreak] = 0
      match_scores[1][:score_tiebreak] = 0
    end
    # return results (ARRAY of won sets count for each player)
    results
  end

  def test_new_score(match_scores)
    # for a new match
    # return ARRAY of won sets count for each player if scores entered in matches/new are valid,
    # eg: 4-2 1-3 10-7
    #     => [ 2, 1 ]
    # returns false otherwise
    results = { sets_won1: 0, sets_won2: 0 } # player 1, player 2
    # test scores entries for first set and second set
    if !match_scores ||
       ((match_scores[0][:score_set1].zero? && match_scores[1][:score_set1].zero?) ||
       (match_scores[0][:score_set2].zero? && match_scores[1][:score_set2].zero?)) # no score entered for either set 1 or set 2
      flash[:alert] = t('.test_scores01_flash')
      false
    else # score entries are OK for set 1 and set 2 => count won sets for each player
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
      elsif (match_scores[0][:score_tiebreak].positive? || match_scores[1][:score_tiebreak].positive?) &&
            (results[:sets_won1] == 2 || results[:sets_won2] == 2) # unnecessary tiebreak score entered
        flash[:notice] = t('.test_scores05_flash')
        true # return a notice but enter the score without the tiebreak score
      else
        if match_scores[0][:score_tiebreak] > match_scores[1][:score_tiebreak]
          results[:sets_won1] += 1
        else
          results[:sets_won2] += 1
        end
        # return ARRAY of won sets count for each player
        [results[:sets_won1], results[:sets_won2]]
      end
    end
  end

  def compute_results(match_scores)
    # compute and returns results (array of won sets count for each player)
    # eg: [ {score_set1: 4, score_set2: 1, score_tiebreak: 10},
    #       {score_set1: 2, score_set2: 3, score_tiebreak: 7} ]
    # =>  [ 2 , 1 ]

    results = { sets_won1: 0, sets_won2: 0 } # player 1, player 2

    # first set
    if match_scores[0][:score_set1] > match_scores[1][:score_set1]
      results[:sets_won1] += 1
    elsif match_scores[0][:score_set1] < match_scores[1][:score_set1]
      results[:sets_won2] += 1
    end

    # second set
    if match_scores[0][:score_set2] > match_scores[1][:score_set2]
      results[:sets_won1] += 1
    elsif match_scores[0][:score_set2] < match_scores[1][:score_set2]
      results[:sets_won2] += 1
    end

    # championship tie break
    if results[:sets_won1] == 1 && results[:sets_won2] == 1
      if match_scores[0][:score_tiebreak] > match_scores[1][:score_tiebreak]
        results[:sets_won1] += 1
      elsif match_scores[0][:score_tiebreak] < match_scores[1][:score_tiebreak]
        results[:sets_won2] += 1
      end
    end
    # return results (ARRAY of won sets count for each player)
    [results[:sets_won1], results[:sets_won2]]
  end

  def score_to_a(score)
    # converts set score "4-3" into array [4, 3]
    score.split("-").map(&:to_i)
  end

  def match_scores_to_a(score)
    # convert score "4-2 1-3 10-7" into match_scores
    # [{:score_set1=>4, :score_set2=>1, :score_tiebreak=>10}, {:score_set1=>2, :score_set2=>3, :score_tiebreak=>7}]
    # first conversion of "4-2 1-3 10-7" into array of arrays [[4, 2], [1, 3], [10, 7]]
    score = score.split.map { |s| s.split("-").map(&:to_i) }
    score << [0, 0] if score.length == 2 # in case no tiebreak
    if score.length >= 2
      match_scores = [{}, {}]
      # eg: 4-2 1-3 10-7 => [{score_set1: 4, score_set2: 1, score_tiebreak: 10}, {score_set1: 2, score_set2: 3, score_tiebreak: 7}]
      [0, 1].each do |index|
        match_scores[index][:score_set1] = score[0][index] # set1
        match_scores[index][:score_set2] = score[1][index] # set2
        match_scores[index][:score_tiebreak] = score[2][index] # tiebreak
      end
      match_scores
    else
      false
    end
  end

  def won_games(user_match_score)
    # sum of games of a player's match card
    user_match_score.score_set1 + user_match_score.score_set2 + user_match_score.score_tiebreak
  end

  def player_opponent(row)
    # in PM Holland Park spreadsheet the score is input as the winner's score and the points_opponent columns
    # provides info as to whether its the payer's score or the opponent's score
    if row[:role_player] && row[:role_opponent]
      if row[:points_opponent].to_i != 20
        player = User.find_by(first_name: row[:first_name_player], last_name: row[:last_name_player])
        player ||= User.create(email: row[:email_player],
          first_name: row[:first_name_player], last_name: row[:last_name_player],
          phone_number: row[:phone_number_player], role: row[:role_player].downcase)
        opponent = User.find_by(first_name: row[:first_name_opponent], last_name: row[:last_name_opponent])
        opponent ||= User.create(email: row[:email_opponent],
          first_name: row[:first_name_opponent], last_name: row[:last_name_opponent],
          phone_number: row[:phone_number_opponent], role: row[:role_opponent].downcase)
      else
        opponent = User.find_by(first_name: row[:first_name_player], last_name: row[:last_name_player])
        opponent ||= User.create(email: row[:email_player],
          first_name: row[:first_name_player], last_name: row[:last_name_player],
          phone_number: row[:phone_number_player], role: row[:role_player].downcase)
        player = User.find_by(first_name: row[:first_name_opponent], last_name: row[:last_name_opponent])
        player ||= User.create(email: row[:email_opponent],
          first_name: row[:first_name_opponent], last_name: row[:last_name_opponent],
          phone_number: row[:phone_number_opponent], role: row[:role_opponent].downcase)
      end
    end
    [player, opponent]
  end
end

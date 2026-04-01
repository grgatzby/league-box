# Matches Controller
# Handles match creation, editing, deletion, and score validation.
# Manages match scores (two sets + optional tiebreak), points calculation, and statistics updates.
# Validates tennis scoring rules and updates UserBoxScore statistics (points, matches, sets, games).
# Allows CSV import of match scores for bulk loading.
class MatchesController < ApplicationController
  REQUIRED_SCORES_HEADERS = [
    "first_name_player", "last_name_player",
    "first_name_opponent", "last_name_opponent",
    "email_player", "email_opponent",
    "box_number", "score_winner"
  ].freeze
  REQUIRED_DOUBLES_SCORES_HEADERS = [
    "first_name1_team", "last_name1_team",
    "first_name2_team", "last_name2_team",
    "first_name1_opponent_team", "last_name1_opponent_team",
    "first_name2_opponent_team", "last_name2_opponent_team",
    "email1_team", "email2_team", "email1_opponent", "email2_opponent",
    "box_number", "score_winner"
  ].freeze
  OPTIONAL_DOUBLES_SCORES_HEADERS = [
    "phone_number1_team", "phone_number2_team", "phone_number1_opponent", "phone_number2_opponent",
    "role1_team", "role2_team", "role1_opponent", "role2_opponent",
    "match_date", "court_nb", "input_user_id", "input_date"
  ].freeze
  OPTIONAL_SCORES_HEADERS = [
    "phone_number_player", "phone_number_opponent", "role_player", "role_opponent",
    "match_date", "court_nb", "input_user_id", "input_date"
  ].freeze
  WINNING_GAMES_PER_SET = 4 # number of winning games per set

  # Display match details with scores for both players
  # Shows match time, court, scores, and referee information
  def show
    @page_from = local_path(params[:page_from])
    set_club_round
    @player = User.find(params[:player])
    @opponent = User.find(params[:opponent])
    # @referee = @referee || User.find_by(role: "referee", club_id: @player.club.id)
    # @referee ||= User.find_by(role: "referee", club_id: @player.club.id) #TO DO : role includes referee
    @referee ||= User.find_by("club_id = ? AND role like ?", @player.club.id, "%referee%")
    @match = Match.find(params[:match_id])
    @player_match_score = match_score(@match, @player)
    @opponent_match_score = match_score(@match, @opponent)
    @round = @match.box.round
    @doubles_match = @round.doubles_format?
    if @doubles_match
      @player_team = @player.teams.includes(:users).find_by(box_id: @match.box_id)
      @opponent_team = @opponent.teams.includes(:users).find_by(box_id: @match.box_id)
      @player_team_tbs = TeamBoxScore.find_by(team_id: @player_team.id, box_id: @match.box_id) if @player_team
      @opponent_team_tbs = TeamBoxScore.find_by(team_id: @opponent_team.id, box_id: @match.box_id) if @opponent_team
    end
  end

  # Display form to create a new match
  # Validates that round has started before allowing score entry
  # Sets maximum match date to round end_date or current time (whichever is earlier)
  def new
    @page_from = local_path(params[:page_from])
    requested_round = Round.find_by(id: params[:round_id])
    set_club_round
    @round = requested_round || @round
    unless @round
      flash[:notice] = t(".valid_round_flash", default: "Please choose a valid round.")
      redirect_back(fallback_location: @page_from || boxes_path)
      return
    end
    @current_player = params[:player] ? User.find(params[:player]) : current_user
    @box = my_own_box(@round, @current_player)
    # Validation: prevent score entry before round start_date
    if @round.start_date > Time.now
      flash[:notice] = t('.round_not_started_flash')
      redirect_back(fallback_location: @page_from)
    else
      if @round.doubles_format?
        @team_a = params[:team_a_id].present? ? Team.find(params[:team_a_id]) : current_user_team_in_box(@box)
        @team_b = params[:team_b_id].present? ? Team.find(params[:team_b_id]) : opposing_team_for(@box, @team_a)
        @box ||= @team_a&.box || @team_b&.box
        unless @team_a && @team_b
          flash[:notice] = t('.team_not_found_flash', default: "No valid opponent team found for this format.")
          redirect_back(fallback_location: @page_from)
          return
        end
      else
        @opponent = User.find(params[:opponent])
      end
      # max match date in the form: user can't post results in the future
      @max_end_date = [@round.end_date, Time.now].min
      @match = Match.new(time: @max_end_date)
      @match.user_match_scores.build
      # Store effective tiebreak points for use in view
      @effective_tiebreak_points = @round.effective_tiebreak_points
      @court_options = sorted_court_options_for_round(@round)
      # the code below was adapted to the previous form where scores of a set were input individually (eg 4 and 1 for 4-1)
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

  # Create a new match with scores for both players
  # Validates scores, calculates points, updates UserBoxScore statistics, and recalculates rankings
  # Score format: "4-2 1-3 10-7" (set1 player1-player2, set2 player1-player2, tiebreak player1-player2)
  # Points calculation:
  #   - Winner: 20 points
  #   - Loser: 10 points per set won + number of games in lost sets
  #   - Tiebreak counts as one set (no points for loser)
  def create
    @match = Match.new
    @page_from = local_path(params[:page_from])
    @current_player = User.find(params[:player])
    round = Round.find(params[:round_id])
    team_a = Team.find_by(id: params[:team_a_id]) if round.doubles_format?
    team_b = Team.find_by(id: params[:team_b_id]) if round.doubles_format?
    @match.box = if round.doubles_format? && team_a && team_b
                   team_a.box
                 else
                   my_own_box(round, @current_player)
                 end
    unless @match.box
      flash[:alert] = t(".invalid_box_flash", default: "Unable to determine the match box.")
      redirect_back(fallback_location: @page_from || boxes_path)
      return
    end
    # Court name in form; must match round format (tennis vs padel)
    round = @match.box.round
    @match.court = Court.find_by(
      name: params[:match][:court_id],
      club_id: round.club_id,
      court_kind: Court.kind_for_tournament_format(round.tournament_format)
    )
    unless @match.court
      flash[:alert] = t(".invalid_court_flash", default: "Invalid court selected.")
      redirect_back(fallback_location: @page_from || boxes_path)
      return
    end

    match_scores = [{}, {}]
    # Example: "4-2 1-3 10-7" => [{score_set1: 4, score_set2: 1, score_tiebreak: 10}, {score_set1: 2, score_set2: 3, score_tiebreak: 7}]
    score_set1 = score_to_a(params[:match][:user_match_scores_attributes]["0"][:score_set1])
    score_set2 = score_to_a(params[:match][:user_match_scores_attributes]["0"][:score_set2])
    score_tiebreak = score_to_a(params[:match][:user_match_scores_attributes]["0"][:score_tiebreak])
    [0, 1].each do |index|
      match_scores[index][:score_set1] = score_set1[index]
      match_scores[index][:score_set2] = score_set2[index]
      match_scores[index][:score_tiebreak] = score_tiebreak[index] || 0
    end

    round = @match.box.round
    if round.doubles_format?
      valid_teams = team_a && team_b &&
                    team_a.box_id == @match.box_id && team_b.box_id == @match.box_id &&
                    team_a.round_id == round.id && team_b.round_id == round.id &&
                    team_a.id != team_b.id
      if current_user.role == "player"
        authorized_submitter = team_a.users.include?(current_user) || team_b.users.include?(current_user)
      else
        authorized_submitter = true
      end
      unless valid_teams && authorized_submitter
        flash[:alert] = t(".unauthorized_doubles_submit", default: "Only players from either doubles team can submit this score.")
        redirect_back(fallback_location: @page_from || boxes_path)
        return
      end
    end
    tiebreak_points = round.effective_tiebreak_points
    test_score = test_new_score(match_scores, tiebreak_points) # ARRAY of won sets count if scores ok, false otherwise
    if test_score
      results = compute_points(match_scores)
      # if score is valid, store match date and match time in UTC Time
      # @match.time = @tz.local_to_utc("#{params[:match][:time]} #{params[:match_id]['time(4i)']}:#{params[:match_id]['time(5i)']}:00".to_datetime)
      # previously, user could enter match hour in the form, but it was considered unnecessary and not ux friendly
      @match.time = @tz.local_to_utc("#{params[:match][:time]} #12:00".to_datetime)
      if round.doubles_format?
        @match.team_a_id = team_a.id
        @match.team_b_id = team_b.id
      end
      @match.save

      input_date = Time.now
      if round.doubles_format?
        create_doubles_scores_and_stats(@match, match_scores, results, input_date)
      else
        # create and fill a user_match_score instance for each player of the match
        UserMatchScore.create(user_id: params[:player], match_id: @match.id)
        UserMatchScore.create(user_id: params[:opponent], match_id: @match.id)

        user_match_scores = UserMatchScore.where(match_id: @match.id)

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
      end

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

  # Display form to edit match scores (admin and referees only)
  # Allows modification of match scores, court, and match date
  # Converts match time from UTC to local time for display
  def edit
    @page_from = local_path(params[:page_from])
    set_club_round
    @match = Match.find(params[:match_id])
    @user_match_scores = UserMatchScore.where(match_id: params[:match_id])
    @current_player = @user_match_scores[0]&.user
    @opponent = @user_match_scores[1]&.user
    if !@match.doubles_match? && @user_match_scores[0] && @user_match_scores[1] &&
       @user_match_scores[0].score_tiebreak.zero? && @user_match_scores[1].score_tiebreak.zero?
      @user_match_scores[0].score_tiebreak = "Na"
      @user_match_scores[1].score_tiebreak = "Na"
    end

    if @match.doubles_match?
      @team_a = @match.team_a
      @team_b = @match.team_b
      team_score_a = TeamMatchScore.find_by(match_id: @match.id, team_id: @team_a&.id)
      team_score_b = TeamMatchScore.find_by(match_id: @match.id, team_id: @team_b&.id)
      @selected_doubles_score_set1 = "#{team_score_a&.score_set1.to_i}-#{team_score_b&.score_set1.to_i}"
      @selected_doubles_score_set2 = "#{team_score_a&.score_set2.to_i}-#{team_score_b&.score_set2.to_i}"
      @selected_doubles_score_tiebreak = if team_score_a&.score_tiebreak.to_i.zero? && team_score_b&.score_tiebreak.to_i.zero?
                                           "Na"
                                         else
                                           "#{team_score_a&.score_tiebreak.to_i}-#{team_score_b&.score_tiebreak.to_i}"
                                         end
      score_input_id = team_score_a&.input_user_id
      score_input_date = team_score_a&.input_date
    else
      score_input_id = @match.user_match_scores[0]&.input_user_id
      score_input_date = @match.user_match_scores[0]&.input_date
    end
    @score_input_by = User.find_by(id: score_input_id)
    @log_time = score_input_date ? @tz.to_local(score_input_date) : nil

    # convert @match.time from UTC time to local time for display in the form
    @match.time += @tz.to_local(@match.time).utc_offset
    @round = @match.box.round
    # max match date in the form: user can't post results in the future
    @max_end_date = [@round.end_date, Time.now].min
    # Store effective tiebreak points for use in view
    @effective_tiebreak_points = @round.effective_tiebreak_points
    @court_options = sorted_court_options_for_round(@round)
  end

  # Update match scores (admin and referees only)
  # Recalculates points and updates UserBoxScore statistics (removes old values, adds new values)
  # Updates rankings after score change
  def update
    match = Match.find(params[:match_id])
    if match.doubles_match?
      round = match.box.round
      input_date = Time.now

      score_set1 = score_to_a(params[:match][:doubles_score_set1])
      score_set2 = score_to_a(params[:match][:doubles_score_set2])
      score_tiebreak = params[:match][:doubles_score_tiebreak] == "Na" ? [0, 0] : score_to_a(params[:match][:doubles_score_tiebreak])
      match_scores = [{}, {}]
      [0, 1].each do |index|
        match_scores[index][:score_set1] = score_set1[index]
        match_scores[index][:score_set2] = score_set2[index]
        match_scores[index][:score_tiebreak] = score_tiebreak[index] || 0
      end

      test_score = test_new_score(match_scores, round.effective_tiebreak_points)
      unless test_score
        redirect_back(fallback_location: edit_match_path(match))
        return
      end

      results = compute_points(match_scores)
      old_match_scores = team_scores_payload_from_match(match)
      old_results = compute_results(old_match_scores)
      apply_doubles_stats_delta(match, old_match_scores, old_results, -1)

      court = Court.find_by(
        name: params[:match][:court_id],
        club_id: match.court.club_id,
        court_kind: Court.kind_for_tournament_format(round.tournament_format)
      )
      unless court
        flash[:alert] = t(".invalid_court_flash", default: "Invalid court selected.")
        redirect_back(fallback_location: edit_match_path(match))
        return
      end
      match.court_id = court.id
      match.time = @tz.local_to_utc("#{params[:match][:time]} #12:00".to_datetime)
      match.save

      [match.team_a_id, match.team_b_id].each_with_index do |team_id, index|
        tms = TeamMatchScore.find_or_initialize_by(match_id: match.id, team_id: team_id)
        tms.score_set1 = match_scores[index][:score_set1]
        tms.score_set2 = match_scores[index][:score_set2]
        tms.score_tiebreak = match_scores[index][:score_tiebreak]
        tms.points = match_scores[index][:points]
        tms.is_winner = (results[index] > results[1 - index])
        tms.input_user_id = current_user.id
        tms.input_date = input_date
        tms.save
      end

      match.user_match_scores.destroy_all
      [match.team_a, match.team_b].each_with_index do |team, index|
        team.users.each do |player|
          UserMatchScore.create!(
            user_id: player.id,
            match_id: match.id,
            score_set1: match_scores[index][:score_set1],
            score_set2: match_scores[index][:score_set2],
            score_tiebreak: match_scores[index][:score_tiebreak],
            points: match_scores[index][:points],
            is_winner: (results[index] > results[1 - index]),
            input_user_id: current_user.id,
            input_date: input_date
          )
        end
      end

      apply_doubles_stats_delta(match, match_scores, results, 1)
      rank_teams(match.box.team_box_scores)
      rank_players(match.box.round.user_box_scores)
      redirect_to local_path(params[:page_from])
      return
    end

    user_match_scores = UserMatchScore.where(match_id: params[:match_id])

    # Store current match points before update (for delta calculation)
    results = compute_results(user_match_scores) # ARRAY of won sets count for each player
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

    # Get round for tiebreak_points validation
    round = match.box.round

    # updates points in user_match_scores and return ARRAY of won sets count for each player
    test_edit_score = test_edit_score(user_match_scores, results, round)

    if test_edit_score
      results = compute_points(user_match_scores)
      # if score entered is valid, store match date and match time in UTC time
      court = Court.find_by(
        name: params[:match][:court_id],
        club_id: match.court.club_id,
        court_kind: Court.kind_for_tournament_format(round.tournament_format)
      )
      unless court
        flash[:alert] = t(".invalid_court_flash", default: "Invalid court selected.")
        redirect_back(fallback_location: edit_match_path(match))
        return
      end
      match.court_id = court.id
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
    @round = Round.find(params[:round_id])
    @round_nb = round_label(@round)
  end

  # Bulk import match scores from CSV file (admin/referee only)
  # Removes existing matches for the round before importing
  # Creates players if they don't exist in the database
  # Updates UserBoxScore statistics and rankings after import
  def create_scores
    csv_file = params[:csv_file]
    delimiter = params[:delimiter].presence || ","
    round = Round.find(params[:round_id])
    overwrite_existing = ActiveModel::Type::Boolean.new.cast(params[:overwrite_existing])

    unless csv_file&.content_type == "text/csv"
      flash[:notice] = t(".file_type_flash", default: "Please upload a CSV file.")
      redirect_back(fallback_location: load_scores_path(round_id: round.id))
      return
    end

    headers = CSV.foreach(csv_file, col_sep: delimiter).first
    normalized_headers = headers.to_a.compact.map { |h| h.to_s.downcase.strip } - ["id"]
    expected_headers = round.doubles_format? ? REQUIRED_DOUBLES_SCORES_HEADERS : REQUIRED_SCORES_HEADERS
    missing_headers = expected_headers - normalized_headers
    if missing_headers.any?
      flash[:notice] = t(".header_flash", default: "Missing required headers: %{headers}", headers: missing_headers.join(", "))
      redirect_back(fallback_location: load_scores_path(round_id: round.id))
      return
    end

    csv_rows = CSV.read(csv_file.path, headers: true, header_converters: :symbol, col_sep: delimiter)
    input_date = Time.current
    conflicts = []
    imported = 0

    csv_rows.each_with_index do |row, idx|
      row_number = idx + 2
      next if row.to_h.values.compact.map(&:to_s).all?(&:blank?)
      # each CSV row is first targeted to a destination box via box_number,
      # so scores are applied to players/teams in that box.
      box = Box.find_by(box_number: row[:box_number], round_id: round.id)
      next unless box

      # then, each CSV row is targeted to a destination match via match_date,
      # so scores are applied to players/teams in that match.
      match_scores = match_scores_to_a(row[:score_winner].to_s)
      next unless match_scores
      results = test_new_score(match_scores, round.effective_tiebreak_points)
      next unless results
      results = compute_points(match_scores)

      court_name = row[:court_nb].presence || "1"
      court = Court.find_by(
        club_id: round.club_id,
        name: court_name,
        court_kind: Court.kind_for_tournament_format(round.tournament_format)
      )
      next unless court

      if round.doubles_format?
        # For doubles/padel, resolve_teams_for_csv_row uses find_team_for_csv_side to match teams by member emails (email1_*, email2_*) when provided,
        # and/or by member names,
        # and if that fails, it falls back to legacy single-player-side matching (which also prefers email first).
        team_a, team_b = resolve_teams_for_csv_row(row, box, round)
        next unless team_a && team_b && team_a.id != team_b.id

        existing_match = Match.where(box_id: box.id)
                              .where("(team_a_id = ? AND team_b_id = ?) OR (team_a_id = ? AND team_b_id = ?)",
                                     team_a.id, team_b.id, team_b.id, team_a.id)
                              .first
        if existing_match && !overwrite_existing
          conflicts << "row #{row_number}: #{team_a.display_name} vs #{team_b.display_name}"
          next
        end
        destroy_match_for_import(existing_match) if existing_match

        match = Match.create!(
          box_id: box.id,
          court_id: court.id,
          team_a_id: team_a.id,
          team_b_id: team_b.id,
          time: row[:match_date].presence || round.start_date
        )
        create_doubles_scores_and_stats(match, match_scores, results, row[:input_date].presence || input_date)
        imported += 1
      else
        # For singles, player matching uses find_player_for_csv_side
        player = find_player_for_csv_side(row, :player, box)
        opponent = find_player_for_csv_side(row, :opponent, box)
        next unless player && opponent && player.id != opponent.id

        existing_match = box.matches.joins(:user_match_scores)
                            .where(user_match_scores: { user_id: [player.id, opponent.id] })
                            .group("matches.id")
                            .having("COUNT(DISTINCT user_match_scores.user_id) = 2")
                            .first
        if existing_match && !overwrite_existing
          conflicts << "row #{row_number}: #{player.last_name} vs #{opponent.last_name}"
          next
        end
        destroy_match_for_import(existing_match) if existing_match

        match = Match.create!(box_id: box.id, court_id: court.id, time: row[:match_date].presence || round.start_date)
        UserMatchScore.create!(user_id: player.id, match_id: match.id)
        UserMatchScore.create!(user_id: opponent.id, match_id: match.id)
        user_match_scores = match.user_match_scores

        [0, 1].each do |index|
          user_match_scores[index].update!(
            score_set1: match_scores[index][:score_set1],
            score_set2: match_scores[index][:score_set2],
            score_tiebreak: match_scores[index][:score_tiebreak],
            points: match_scores[index][:points],
            is_winner: (results[index] > results[1 - index]),
            input_user_id: row[:input_user_id].presence || current_user.id,
            input_date: row[:input_date].presence || input_date
          )
        end

        [0, 1].each do |index|
          ums = user_match_scores[index]
          user_box_score = UserBoxScore.find_by(box_id: match.box_id, user_id: ums.user_id)
          next unless user_box_score

          user_box_score.points += ums.points
          user_box_score.games_won += won_games(ums)
          user_box_score.games_played += won_games(ums) + won_games(user_match_scores[1 - index])
          user_box_score.sets_won += results[index]
          user_box_score.sets_played += results.sum
          user_box_score.matches_won += results[index] > results[1 - index] ? 1 : 0
          user_box_score.matches_played += 1
          user_box_score.save
        end
        imported += 1
      end
    end

    if conflicts.any? && !overwrite_existing
      flash[:alert] = t(".overwrite_needed_flash",
                        default: "%{count} existing matches found for the same pair/team. Tick overwrite to replace them.",
                        count: conflicts.size)
      redirect_to load_scores_path(round_id: round.id, delimiter: delimiter)
      return
    end

    rank_players(round.user_box_scores)
    flash[:notice] = t(".imported_flash", default: "%{count} matches imported.", count: imported)
    redirect_to boxes_path(round_id: round.id, club_id: round.club_id)
  end

  private

  def sorted_court_options_for_round(round)
    Court.for_round(round).pluck(:name).sort_by do |name|
      name.to_s.scan(/\d+|\D+/).map { |part| part.match?(/\A\d+\z/) ? [0, part.to_i] : [1, part.downcase] }
    end
  end

  def current_user_team_in_box(box)
    return nil unless box

    box.teams.includes(:users).find { |team| team.users.include?(current_user) }
  end

  def opposing_team_for(box, team)
    return nil unless box && team

    box.teams.where.not(id: team.id).first
  end

  def create_doubles_scores_and_stats(match, match_scores, results, input_date)
    team_ids = [match.team_a_id, match.team_b_id]
    team_scores = []
    [0, 1].each do |index|
      tms = TeamMatchScore.create(
        team_id: team_ids[index],
        match_id: match.id,
        score_set1: match_scores[index][:score_set1],
        score_set2: match_scores[index][:score_set2],
        score_tiebreak: match_scores[index][:score_tiebreak],
        points: match_scores[index][:points],
        is_winner: (results[index] > results[1 - index]),
        input_user_id: current_user.id,
        input_date: input_date
      )
      team_scores << tms
    end

    # Mirror team match score on each team member to keep backward-compatible player stats and views
    [0, 1].each do |index|
      team = Team.includes(:users).find(team_ids[index])
      team.users.each do |player|
        ums = UserMatchScore.create(user_id: player.id, match_id: match.id)
        ums.update(
          score_set1: match_scores[index][:score_set1],
          score_set2: match_scores[index][:score_set2],
          score_tiebreak: match_scores[index][:score_tiebreak],
          points: match_scores[index][:points],
          is_winner: (results[index] > results[1 - index]),
          input_user_id: current_user.id,
          input_date: input_date
        )

        user_box_score = UserBoxScore.find_by(box_id: match.box_id, user_id: player.id)
        next unless user_box_score

        own_games = won_games(ums).to_i
        opp_games = team_scores[1 - index].score_set1.to_i + team_scores[1 - index].score_set2.to_i + team_scores[1 - index].score_tiebreak.to_i
        won_match = results[index] > results[1 - index] ? 1 : 0

        user_box_score.points = user_box_score.points.to_i + ums.points.to_i
        user_box_score.games_won = user_box_score.games_won.to_i + own_games
        user_box_score.games_played = user_box_score.games_played.to_i + own_games + opp_games
        user_box_score.sets_won = user_box_score.sets_won.to_i + results[index].to_i
        user_box_score.sets_played = user_box_score.sets_played.to_i + results.sum.to_i
        user_box_score.matches_won = user_box_score.matches_won.to_i + won_match
        user_box_score.matches_played = user_box_score.matches_played.to_i + 1
        user_box_score.save
      end
    end

    [0, 1].each do |index|
      team = Team.find(team_ids[index])
      team_box_score = TeamBoxScore.find_or_create_by(team_id: team.id, box_id: match.box_id)
      own_games = match_scores[index][:score_set1].to_i + match_scores[index][:score_set2].to_i + match_scores[index][:score_tiebreak].to_i
      opp_games = match_scores[1 - index][:score_set1].to_i + match_scores[1 - index][:score_set2].to_i + match_scores[1 - index][:score_tiebreak].to_i
      won_match = results[index] > results[1 - index] ? 1 : 0

      team_box_score.points = team_box_score.points.to_i + match_scores[index][:points].to_i
      team_box_score.games_won = team_box_score.games_won.to_i + own_games
      team_box_score.games_played = team_box_score.games_played.to_i + own_games + opp_games
      team_box_score.sets_won = team_box_score.sets_won.to_i + results[index].to_i
      team_box_score.sets_played = team_box_score.sets_played.to_i + results.sum.to_i
      team_box_score.matches_won = team_box_score.matches_won.to_i + won_match
      team_box_score.matches_played = team_box_score.matches_played.to_i + 1
      team_box_score.save
    end

    rank_teams(match.box.team_box_scores)
    rank_players(match.box.round.user_box_scores)
  end

  def team_scores_payload_from_match(match)
    team_scores = match.team_match_scores.index_by(&:team_id)
    [match.team_a_id, match.team_b_id].map do |team_id|
      tms = team_scores[team_id]
      {
        score_set1: tms&.score_set1.to_i,
        score_set2: tms&.score_set2.to_i,
        score_tiebreak: tms&.score_tiebreak.to_i,
        points: tms&.points.to_i
      }
    end
  end

  def apply_doubles_stats_delta(match, match_scores, results, factor)
    [match.team_a, match.team_b].each_with_index do |team, index|
      own_games = match_scores[index][:score_set1] + match_scores[index][:score_set2] + match_scores[index][:score_tiebreak]
      opp_games = match_scores[1 - index][:score_set1] + match_scores[1 - index][:score_set2] + match_scores[1 - index][:score_tiebreak]
      won_match = results[index] > results[1 - index] ? 1 : 0

      team_box_score = TeamBoxScore.find_or_create_by(team_id: team.id, box_id: match.box_id)
      team_box_score.points = team_box_score.points.to_i + factor * match_scores[index][:points].to_i
      team_box_score.games_won = team_box_score.games_won.to_i + factor * own_games.to_i
      team_box_score.games_played = team_box_score.games_played.to_i + factor * (own_games.to_i + opp_games.to_i)
      team_box_score.sets_won = team_box_score.sets_won.to_i + factor * results[index].to_i
      team_box_score.sets_played = team_box_score.sets_played.to_i + factor * results.sum.to_i
      team_box_score.matches_won = team_box_score.matches_won.to_i + factor * won_match.to_i
      team_box_score.matches_played = team_box_score.matches_played.to_i + factor.to_i
      team_box_score.save

      team.users.each do |player|
        user_box_score = UserBoxScore.find_by(box_id: match.box_id, user_id: player.id)
        next unless user_box_score

        user_box_score.points = user_box_score.points.to_i + factor * match_scores[index][:points].to_i
        user_box_score.games_won = user_box_score.games_won.to_i + factor * own_games.to_i
        user_box_score.games_played = user_box_score.games_played.to_i + factor * (own_games.to_i + opp_games.to_i)
        user_box_score.sets_won = user_box_score.sets_won.to_i + factor * results[index].to_i
        user_box_score.sets_played = user_box_score.sets_played.to_i + factor * results.sum.to_i
        user_box_score.matches_won = user_box_score.matches_won.to_i + factor * won_match.to_i
        user_box_score.matches_played = user_box_score.matches_played.to_i + factor.to_i
        user_box_score.save
      end
    end
  end

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

  # Used by CSV import overwrite mode. Handles both singles and doubles cleanup before replacement.
  def destroy_match_for_import(match)
    return unless match

    if match.doubles_match?
      old_match_scores = team_scores_payload_from_match(match)
      old_results = compute_results(old_match_scores)
      apply_doubles_stats_delta(match, old_match_scores, old_results, -1)
      TeamMatchScore.where(match_id: match.id).delete_all
      UserMatchScore.where(match_id: match.id).delete_all
      match.destroy
    else
      destroy_match(match)
    end
  end

  # Validate match scores for an edit
  # Similar to #test_new_score but uses existing results for validation
  # Returns: true if valid, false otherwise
  def test_edit_score(match_scores, results, round)
    tiebreak_points = round.effective_tiebreak_points
    if (match_scores[0][:score_set1] < WINNING_GAMES_PER_SET && match_scores[1][:score_set1] < WINNING_GAMES_PER_SET) ||
       (match_scores[0][:score_set2] < WINNING_GAMES_PER_SET && match_scores[1][:score_set2] < WINNING_GAMES_PER_SET)
      flash[:alert] = t('.test_scores01_flash') # A score must be entered for each set.
      false
    elsif (match_scores[0][:score_tiebreak] < tiebreak_points && match_scores[1][:score_tiebreak] < tiebreak_points) &&
          (results[0] == 1 || results[1] == 1) # no score entered for the tiebreak with 1 set each
      flash[:alert] = t('.test_scores02_flash') # There must be a winner for the tiebreak.
      false
    elsif (match_scores[0][:score_set1] == WINNING_GAMES_PER_SET && match_scores[1][:score_set1] == WINNING_GAMES_PER_SET) ||
          (match_scores[0][:score_set2] == WINNING_GAMES_PER_SET && match_scores[1][:score_set2] == WINNING_GAMES_PER_SET)
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

  # Calculate points for both players based on match scores
  # Parameters: match_scores (array of 2 hashes with score_set1, score_set2, score_tiebreak)
  # Returns: results (array of won sets count for each player)
  # Also modifies match_scores to add :points key
  # Points rules:
  #   - Winner: 20 points total
  #   - Loser: 10 points per set won + number of games in lost sets
  #   - Tiebreak counts as one set (no points for loser)
  # Example: 4-2 1-3 10-7 => Winner: 20 points, Loser: 12 points (10+2 for lost set1, +0 for lost set2)
  def compute_points(match_scores)

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

  # Validate match scores for a new match
  # Checks: both sets have scores, tiebreak present if sets are 1-1, tiebreak margin is 2+ points,
  # and winning tiebreak score reaches the configured threshold.
  # Returns: ARRAY [sets_won_player1, sets_won_player2] if valid, false otherwise
  # Example: 4-2 1-3 10-7 => [2, 1] (player1 wins 2 sets)
  def test_new_score(match_scores, tiebreak_points)
    results = { sets_won1: 0, sets_won2: 0 } # player 1, player 2
    # test scores entries for first set and second set
    if !match_scores ||
       ((match_scores[0][:score_set1].zero? && match_scores[1][:score_set1].zero?) ||
       (match_scores[0][:score_set2].zero? && match_scores[1][:score_set2].zero?)) # no score entered for either set 1 or set 2
      flash[:alert] = t('.test_scores01_flash')
      false
    else # score entries are OK for set 1 and set 2 => count won sets for each player
      # first set
      if match_scores[0][:score_set1] == WINNING_GAMES_PER_SET && match_scores[1][:score_set1] < WINNING_GAMES_PER_SET
        results[:sets_won1] += 1
      else
        results[:sets_won2] += 1
      end
      # second set
      if match_scores[0][:score_set2] == WINNING_GAMES_PER_SET && match_scores[1][:score_set2] < WINNING_GAMES_PER_SET
        results[:sets_won1] += 1
      else
        results[:sets_won2] += 1
      end

      # test score entries for the tiebreak
      if match_scores[0][:score_tiebreak].zero? && match_scores[1][:score_tiebreak].zero? &&
         (results[:sets_won1] == 1 || results[:sets_won2] == 1) # no score entered for the tiebreak with 1 set each
        # TO DO : if unfinished match are permitted (create migration for new club attribute) separate 2 cases here
         flash[:alert] = t('.test_scores02_flash')
        false
      elsif (match_scores[0][:score_tiebreak].positive? || match_scores[1][:score_tiebreak].positive?) &&
            (results[:sets_won1] == 2 || results[:sets_won2] == 2) # unnecessary tiebreak score entered
        flash[:notice] = t('.test_scores05_flash')
        true # return a notice but enter the score without the tiebreak score
      else
        # Validate tiebreak threshold and margin of 2 points
        max_score = [match_scores[0][:score_tiebreak], match_scores[1][:score_tiebreak]].max
        if (max_score < tiebreak_points || (match_scores[0][:score_tiebreak] - match_scores[1][:score_tiebreak]).abs < 2) &&
          (results[:sets_won1] == 1 || results[:sets_won2] == 1) # no score entered for the tiebreak with 1 set each
          flash[:alert] = t('.test_scores04_flash') # Tiebreak: need 2 points clear.
          false
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
    #raise "test_new_score: #{match_scores[0][:score_set1]} #{match_scores[1][:score_set1]} #{match_scores[0][:score_set2]} #{match_scores[1][:score_set2]} #{match_scores[0][:score_tiebreak]} #{match_scores[1][:score_tiebreak]} #{results[:sets_won1]} #{results[:sets_won2]}"
  end

  # Calculate number of sets won by each player
  # Parameters: match_scores (array of 2 hashes with score_set1, score_set2, score_tiebreak)
  # Returns: [sets_won_player1, sets_won_player2]
  # Tiebreak only counted if sets are 1-1
  # Example: [{score_set1: 4, score_set2: 1, score_tiebreak: 10}, {score_set1: 2, score_set2: 3, score_tiebreak: 7}] => [2, 1]
  def compute_results(match_scores)

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

  # Convert set score string to array of two game counts (one per player).
  # Example: "4-3" => [4, 3]. Blank, nil, or one-sided input => [0, 0] / padded so [index] is never nil.
  def score_to_a(score)
    return [0, 0] if score.blank?

    nums = score.to_s.split("-").map(&:to_i)
    [nums[0] || 0, nums[1] || 0]
  end

  # Convert full match score string to match_scores array
  # Example: "4-2 1-3 10-7" => [{score_set1: 4, score_set2: 1, score_tiebreak: 10}, {score_set1: 2, score_set2: 3, score_tiebreak: 7}]
  # Converts string to array of arrays first: [[4, 2], [1, 3], [10, 7]]
  def match_scores_to_a(score)
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

  # Calculate total games won by a player in a match
  # Sum of games from set1, set2, and tiebreak
  def won_games(user_match_score)
    user_match_score.score_set1 + user_match_score.score_set2 + user_match_score.score_tiebreak
  end

  # Determine winner and loser from CSV row
  # CSV format: score is winner's score, points_opponent column indicates if player won (20 points = win)
  # Creates players if they don't exist in database
  # Returns: [winner, loser] array
  def winner_loser(row)
    if row[:role_player] && row[:role_opponent]
      if row[:points_opponent].to_i != 20
        winner = User.find_by(first_name: row[:first_name_player], last_name: row[:last_name_player])
        winner ||= User.create(email: row[:email_player],
          first_name: row[:first_name_player], last_name: row[:last_name_player],
          phone_number: row[:phone_number_player], role: row[:role_player].downcase)
        loser = User.find_by(first_name: row[:first_name_opponent], last_name: row[:last_name_opponent])
        loser ||= User.create(email: row[:email_opponent],
          first_name: row[:first_name_opponent], last_name: row[:last_name_opponent],
          phone_number: row[:phone_number_opponent], role: row[:role_opponent].downcase)
      else
        loser = User.find_by(first_name: row[:first_name_player], last_name: row[:last_name_player])
        loser ||= User.create(email: row[:email_player],
          first_name: row[:first_name_player], last_name: row[:last_name_player],
          phone_number: row[:phone_number_player], role: row[:role_player].downcase)
        winner = User.find_by(first_name: row[:first_name_opponent], last_name: row[:last_name_opponent])
        winner ||= User.create(email: row[:email_opponent],
          first_name: row[:first_name_opponent], last_name: row[:last_name_opponent],
          phone_number: row[:phone_number_opponent], role: row[:role_opponent].downcase)
      end
    end
    [winner, loser]
  end

  def find_player_for_csv_side(row, side, box)
    # if email_player / email_opponent is present, try a case-insensitive email match first,
    # if not found (or email blank), fall back to first+last name match within that box.
    email = row[:"email_#{side}"].to_s.strip
    first_name = row[:"first_name_#{side}"].to_s.strip
    last_name = row[:"last_name_#{side}"].to_s.strip

    users_in_box = box.user_box_scores.includes(:user).map(&:user)
    if email.present?
      users_in_box.find { |u| u.email.to_s.casecmp(email).zero? } ||
        users_in_box.find { |u| u.first_name.to_s.casecmp(first_name).zero? && u.last_name.to_s.casecmp(last_name).zero? }
    else
      users_in_box.find { |u| u.first_name.to_s.casecmp(first_name).zero? && u.last_name.to_s.casecmp(last_name).zero? }
    end
  end

  def resolve_teams_for_csv_row(row, box, round)
    # it can match teams by member emails (email1_*, email2_*) when provided,
    # and/or by member names,
    # and if that fails, it falls back to legacy single-player-side matching (which also prefers email first).


    teams_in_box = box.teams.includes(:users).where(round_id: round.id)
    team_a = find_team_for_csv_side(row, teams_in_box, :team)
    team_b = find_team_for_csv_side(row, teams_in_box, :opponent_team)

    # Backward compatibility for legacy doubles CSV headers using one player per side.
    if team_a.nil? || team_b.nil?
      player = find_player_for_csv_side(row, :player, box)
      opponent = find_player_for_csv_side(row, :opponent, box)
      return [nil, nil] unless player && opponent

      team_a = teams_in_box.find { |team| team.users.include?(player) }
      team_b = teams_in_box.find { |team| team.users.include?(opponent) }
    end

    [team_a, team_b]
  end

  def find_team_for_csv_side(row, teams_in_box, side)
    first_name1 = row[:"first_name1_#{side}"].to_s.strip
    last_name1 = row[:"last_name1_#{side}"].to_s.strip
    first_name2 = row[:"first_name2_#{side}"].to_s.strip
    last_name2 = row[:"last_name2_#{side}"].to_s.strip
    email1 = row[:"email1_#{side}"].to_s.strip
    email2 = row[:"email2_#{side}"].to_s.strip
    return nil if [first_name1, last_name1, first_name2, last_name2, email1, email2].all?(&:blank?)

    teams_in_box.find do |team|
      players = team.users.sort_by { |u| [u.last_name.to_s.upcase, u.first_name.to_s.upcase, u.id.to_i] }
      next false unless players.size >= 2

      team_players = players.first(2)
      team_emails = team_players.map { |u| u.email.to_s.downcase }
      csv_emails = [email1, email2].map { |e| e.to_s.downcase }.reject(&:blank?)

      email_match = csv_emails.empty? || csv_emails.all? { |e| team_emails.include?(e) }

      csv_players = [[first_name1, last_name1], [first_name2, last_name2]].reject { |fname, lname| fname.blank? && lname.blank? }
      name_match = csv_players.empty? || csv_players.all? do |fname, lname|
        team_players.any? do |u|
          u.first_name.to_s.casecmp(fname.to_s).zero? && u.last_name.to_s.casecmp(lname.to_s).zero?
        end
      end

      email_match && name_match
    end
  end
end

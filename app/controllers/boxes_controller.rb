class BoxesController < ApplicationController
  require "csv"
  require "fileutils"
  require "securerandom"
  helper_method :box_matches, :my_box?  # allows the #box_matches method to be called from views
  DAYS_BEFORE_NEW_ROUND_CREATION = 15
  PLAYERS_HEADERS = ["id", "club_id", "email", "first_name", "last_name", "nickname", "phone_number", "role", "box_number"]
  TOURNAMENT_SINGLES_HEADERS = ["first_name", "last_name", "phone_number", "email"]
  TOURNAMENT_DOUBLES_HEADERS = ["first_name1", "last_name1", "phone_number1", "email1",
                                "first_name2", "last_name2", "phone_number2", "email2"]

  def index
    # displays all boxes and the shared select_round form
    @page_from = params[:page_from]
    set_club_round # sets variables @club, @round and @boxes (ApplicationController)
    # @my_box = 0
    # @boxes&.each { |box| @my_box = box if my_box?(box) } # Ruby Safe Navigation (instead of if @boxes each_block else nil end)
    @my_box = my_own_box(@round)
    if @round
      @doubles_mode = @round.doubles_format?
      init_stats
      if current_user == @admin
        @format_rounds = Round.where(club_id: @round.club_id, tournament_format: @round.tournament_format).order(:start_date)
        @last_format_round = @format_rounds.last
      end
      days_left = (@round.end_date - Date.today).to_i # nb of days til then end of the round
      # admin : creates button appears in last days or after if round is the most recent
      @new_round_required = (days_left <= DAYS_BEFORE_NEW_ROUND_CREATION) && (round_dropdown_to_start_date(@rounds_dropdown.first) == @round.start_date)
      # referee : request button appears only before end of the last round
      @new_round_request = days_left.positive? && @new_round_required
    end
  end

  # Admin-only: destroy one round in the current tournament format and all dependent records.
  # Choice can be explicit round id, "current" (default), or "last".
  def destroy_round
    set_club_round
    unless current_user == @admin
      redirect_back(fallback_location: boxes_path, alert: "Unauthorized.")
      return
    end
    unless @round
      redirect_back(fallback_location: boxes_path, alert: "No active round selected.")
      return
    end

    scope = Round.where(club_id: @round.club_id, tournament_format: @round.tournament_format).order(:start_date)
    target_round = round_to_destroy_from_params(scope)
    unless target_round
      redirect_back(fallback_location: boxes_path(round_id: @round.id, club_id: @round.club_id), alert: "Round not found in current format.")
      return
    end

    # Keep "general" chatroom and remove round-bound chatrooms (chatrooms.box_id).
    general_id = @general_chatroom&.id
    box_ids = target_round.boxes.pluck(:id)
    chatroom_ids = Chatroom.where(box_id: box_ids).pluck(:id)
    chatroom_ids -= [general_id] if general_id
    Chatroom.where(id: chatroom_ids).destroy_all if chatroom_ids.any?

    label = round_label(target_round)
    target_round.destroy!

    next_round = scope.reload.last
    if next_round
      redirect_to boxes_path(round_id: next_round.id, club_id: next_round.club_id),
                  notice: "Round #{label} deleted."
    else
      redirect_to boxes_path(club_id: @round.club_id), notice: "Round #{label} deleted."
    end
  end

  def index_expanded
    index
  end

  def show
    # displays one box in table view, links to view and edit match cards
    unless params[:id].to_i.zero?
      @page_from = params[:page_from]
      @box = Box.find(params[:id])
      @id_next_box = Box.find_by(box_number: @box.box_number + 1, round_id: @box.round) || Box.find_by(box_number: 1, round_id: @box.round).id
      @id_previous_box = Box.find_by(box_number: @box.box_number - 1, round_id: @box.round) || Box.find_by(box_number: Box.where(round_id: @box.round).count, round_id: @box.round).id
      @round = @box.round
      @my_box = my_own_box(@round)
      init_stats
      @round_nb = round_label(@round)
      @doubles_mode = @round.doubles_format?
      # @box_matches is an array of [user_box_score , matches_details(user), user]
      # matches_details(user) is an array of [match, opponent, user_score, opponent_score]
      @box_matches = box_matches(@box) # sorted by descending points scores (or teams in doubles)
      @is_this_my_box = if @doubles_mode
                          @box.teams.includes(:users).any? { |team| team.users.include?(current_user) }
                        else
                          my_box?(@box)
                        end
    end
  end

  def show_list
    # displays one box in list view, links to view and edit match cards
    show # inherit from #show
  end

  def my_scores
    # view player's box and select enter new score / view played match
    # open the box chatroom if necessary and link to access it
    @page_from = params[:page_from]
    @current_player = current_user
    if params[:id].to_i.zero?
      # previously, passing 0 to my_scores_path, forced user to choose a round
      # now the last round is automatically selected in applications#set_club_round
      set_club_round
      @my_box = my_own_box(@round)
      @box = @my_box
      @user_not_in_round = true unless @box
    else
      @box = Box.find(params[:id])
      @is_this_my_box = my_box?(@box)
      @round_nb = round_label(@box.round)
    end
    if @box
      @round = @box.round
      @my_box = my_own_box(@round)
      init_stats
      @doubles_mode = @round.doubles_format?
      if @doubles_mode
        @my_team = @box.teams.includes(:users).find { |team| team.users.include?(@current_player) }
        @my_team_matches = []
        if @my_team
          @box.teams.includes(:users).each do |team|
            match_played = Match.where(box_id: @box.id).where(
              "(team_a_id = ? AND team_b_id = ?) OR (team_a_id = ? AND team_b_id = ?)",
              @my_team.id, team.id, team.id, @my_team.id
            ).first
            team_box_score = TeamBoxScore.find_by(team_id: team.id, box_id: @box.id)
            @my_team_matches << [team, team_box_score, match_played]
          end
        end
      else
        @my_matches = []
        @box.user_box_scores.each do |user_box_score|
          opponent_matches = user_matches(user_box_score.user, @box)
          current_player_matches = user_matches(@current_player, @box)
          match_played = (opponent_matches & current_player_matches)[0]
          @my_matches << [user_box_score, match_played]
        end
        @my_matches = @my_matches.sort { |a, b| b[0].points <=> a[0].points }
      end
      if !@box.chatroom || @box.chatroom == @general_chatroom
        # creates (and opens) a new chatroom if it does not exist yet or if it is still set to "general":
        # rationale : the Chatroom class was migrated after the Box class (with: chatroom has one box)
        # and the migration script assigned the #general chatroom by default to existing boxes.
        # The name format: "[Club name] - R[Round id]:B[Box number]"
        # a chatroom is box and round specific:
        # players can access it when visiting My Scores or from the navbar menu Chatrooms
        @chatroom = Chatroom.create(name: chatroom_name(@box))
        @chatroom.update(box: @box)

        # Broadcast notification to all users with access
        @chatroom.users_with_access.each do |user|
          notification_data = {
            type: "new_chatroom",
            chatroom_id: @chatroom.id,
            chatroom_name: @chatroom.name
          }

          ActionCable.server.broadcast(
            "notifications_#{user.id}",
            notification_data.to_json
          )
        end
      else
        @chatroom = @box.chatroom
      end

      # Mark chatroom as read for current user when displayed via my_scores
      if @chatroom
        ChatroomRead.find_or_create_by(user: current_user, chatroom: @chatroom).update(last_read_at: Time.current)
      end
    end
  end

  def mark_chatroom_as_read(chatroom)
    ChatroomRead.find_or_create_by(user: current_user, chatroom: chatroom).update(last_read_at: Time.current)
  end

  def round_boxes_to_csv
    # exports for the selected round a list of players and the referee to a csv file
    # credits https://www.freecodecamp.org/news/export-a-database-table-to-csv-using-a-simple-ruby-script-2/
    round = Round.find(params[:round_id])
    # file = Rails.root.join('public', 'data.csv')
    file = "#{Rails.root}/public/data.csv"
    boxes = round.boxes.includes([:user_box_scores]).sort { |a, b| a.box_number <=> b.box_number }
    user_box_scores = boxes.flat_map(&:user_box_scores)
    # 'referee' or 'player referee' : User.find_by("club_id = ? AND role like ?", round.club_id, "%referee%")
    referee = User.find_by(role: "referee", club_id: round.club_id) #only 'referee', not 'player referee'
    CSV.open(file, 'w') do |writer|
      # table headers
      # PLAYERS_HEADERS = ["id", "club_id", "email", "first_name", "last_name", "nickname", "phone_number", "role", "box_number"]
      writer << PLAYERS_HEADERS
      user_box_scores.each do |ubs|
        writer << [ubs.user_id, round.club_id,
                   ubs.user.email,
                   ubs.user.first_name, ubs.user.last_name, ubs.user.nickname,
                   ubs.user.phone_number, ubs.user.role, ubs.box.box_number]
      end
      if referee
        writer << [referee.id, round.club_id,
                  referee.email,
                  referee.first_name, referee.last_name, referee.nickname,
                  referee.phone_number, referee.role]
      end
    end
    download_csv(file.pathmap, "Boxes-R#{round_label(round)}", round.club.name, "boxes#round_boxes_to_csv")
  end

  def round_scores_to_csv
    # exports the scores to a csv file for the selected round
    # complying with the expected format for matches#create_scores
    # credits https://www.freecodecamp.org/news/export-a-database-table-to-csv-using-a-simple-ruby-script-2/
    round = Round.find(params[:round_id])
    file = "#{Rails.root}/public/data.csv"
    includes = if round.doubles_format?
                 { matches: [:team_match_scores, { team_a: :users }, { team_b: :users }, :court] }
               else
                 { matches: [{ user_match_scores: :user }, :court] }
               end
    matches = round.boxes.includes(includes).order(:box_number).flat_map(&:matches)

    CSV.open(file, "w", col_sep: ",") do |writer|
      writer << score_csv_headers_for_round(round)
      matches.each do |match|
        row = if round.doubles_format?
                doubles_score_csv_row(match)
              else
                singles_score_csv_row(match)
              end
        writer << row if row
      end
    end
    download_csv(file.pathmap, "Scores-R#{round_label(round)}", round.club.name, "boxes#round_scores_to_csv")
  end

  def tournament_players_to_csv
    round = Round.find(params[:round_id])
    return redirect_back(fallback_location: boxes_path(round_id: round.id, club_id: round.club_id), alert: "Unauthorized.") unless current_user == @admin

    file = "#{Rails.root}/public/data.csv"
    CSV.open(file, "w", col_sep: ",") do |writer|
      if round.tournament_format == "singles_tennis"
        writer << TOURNAMENT_SINGLES_HEADERS
        round.boxes.includes(user_box_scores: :user).order(:box_number).each do |box|
          box.user_box_scores.each do |ubs|
            user = ubs.user
            writer << [user.first_name, user.last_name, user.phone_number, user.email]
          end
        end
      else
        writer << TOURNAMENT_DOUBLES_HEADERS
        round.boxes.includes(teams: :users).order(:box_number).each do |box|
          box.teams.each do |team|
            players = team.users.sort_by { |u| [u.last_name.to_s.upcase, u.first_name.to_s.upcase] }
            p1 = players[0]
            p2 = players[1]
            writer << [p1&.first_name, p1&.last_name, p1&.phone_number, p1&.email,
                       p2&.first_name, p2&.last_name, p2&.phone_number, p2&.email]
          end
        end
      end
    end
    download_csv(file.pathmap, "TournamentPlayers-R#{round_label(round)}", round.club.name, "boxes#tournament_players_to_csv")
  end

  def player_match_scores_options
    @round = Round.find(params[:round_id])
    return redirect_back(fallback_location: boxes_path(round_id: @round.id, club_id: @round.club_id), alert: "Unauthorized.") unless current_user == @admin
  end

  # Admin-only export with compact headers for player-vs-opponent score imports.
  # Headers: first_name_player,last_name_player,first_name_opponent,last_name_opponent,box_number,score_winner
  def player_match_scores_to_csv
    round = Round.find(params[:round_id])
    return redirect_back(fallback_location: boxes_path(round_id: round.id, club_id: round.club_id), alert: "Unauthorized.") unless current_user == @admin

    include_input_user_id = ActiveModel::Type::Boolean.new.cast(params[:include_input_user_id])
    include_roles = ActiveModel::Type::Boolean.new.cast(params[:include_roles])
    include_court_nb = ActiveModel::Type::Boolean.new.cast(params[:include_court_nb])

    export_dir = Rails.root.join("public", "exports")
    FileUtils.mkdir_p(export_dir)
    safe_round_label = round_label(round).to_s.gsub(/[^0-9A-Za-z_-]/, "-")
    export_filename = "player-match-scores-r#{safe_round_label}-boxes#player_match_scores_to_csv-#{Time.current.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(4)}.csv"
    file = export_dir.join(export_filename)

    CSV.open(file, "w", col_sep: ",") do |writer|
      if round.doubles_format?
        headers = [
          "first_name1_team", "last_name1_team",
          "first_name2_team", "last_name2_team",
          "email1_team", "email2_team",
          "first_name1_opponent_team", "last_name1_opponent_team",
          "first_name2_opponent_team", "last_name2_opponent_team",
          "email1_opponent", "email2_opponent",
          "box_number", "score_winner"
        ]
        headers += ["role1_team", "role2_team", "role1_opponent", "role2_opponent"] if include_roles
        headers << "court_nb" if include_court_nb
        headers << "input_user_id" if include_input_user_id
        writer << headers
      else
        headers = ["first_name_player", "last_name_player", "first_name_opponent", "last_name_opponent", "box_number", "score_winner"]
        headers += ["role_player", "role_opponent"] if include_roles
        headers << "court_nb" if include_court_nb
        headers << "input_user_id" if include_input_user_id
        writer << headers
      end
      boxes_includes = if round.doubles_format?
                         { matches: [:team_match_scores, { team_a: :users }, { team_b: :users }, :court] }
                       else
                         { matches: [{ user_match_scores: :user }, :court] }
                       end
      round.boxes.includes(boxes_includes).order(:box_number).each do |box|
        box.matches.each do |match|
          if round.doubles_format?
            team_a_players = ordered_team_players(match.team_a)
            team_b_players = ordered_team_players(match.team_b)
            score = score_winner_from_team_scores(match)
            next unless team_a_players.size >= 2 && team_b_players.size >= 2 && score.present?

            row = [
              team_a_players[0].first_name, team_a_players[0].last_name,
              team_a_players[1].first_name, team_a_players[1].last_name,
              team_a_players[0].email, team_a_players[1].email,
              team_b_players[0].first_name, team_b_players[0].last_name,
              team_b_players[1].first_name, team_b_players[1].last_name,
              team_b_players[0].email, team_b_players[1].email,
              box.box_number, score
            ]
            input_source = match.team_match_scores.find { |s| s.team_id == match.team_a_id } || match.team_match_scores.first
            row += [team_a_players[0].role, team_a_players[1].role, team_b_players[0].role, team_b_players[1].role] if include_roles
            row << match.court&.name if include_court_nb
            row << (input_source&.input_user_id || current_user.id) if include_input_user_id
            writer << row
          else
            next if match.user_match_scores.size < 2

            s0 = match.user_match_scores[0]
            s1 = match.user_match_scores[1]
            p0 = s0&.user
            p1 = s1&.user
            score = score_winner_board(match)
            next unless p0 && p1 && score.present?

            row = [p0.first_name, p0.last_name, p1.first_name, p1.last_name, box.box_number, score]
            row += [p0.role, p1.role] if include_roles
            row << match.court&.name if include_court_nb
            row << (s0&.input_user_id || current_user.id) if include_input_user_id
            writer << row
          end
        end
      end
    end
    if ActiveModel::Type::Boolean.new.cast(params[:redirect_back])
      redirect_to boxes_path(round_id: round.id,
                             club_id: round.club_id,
                             export_status: "ok",
                             export_csv: export_filename)
    else
      send_file file,
                filename: csv_download_filename(round.club.name, "PlayerMatchScores-R#{round_label(round)}", "boxes#player_match_scores_to_csv"),
                disposition: "attachment",
                type: "text/csv"
    end
  rescue StandardError => e
    Rails.logger.error("player_match_scores_to_csv failed: #{e.class} - #{e.message}")
    redirect_to boxes_path(round_id: round.id, club_id: round.club_id, export_status: "ko"),
                alert: t("boxes.index.export_csv_ko")
  end

  private

  def round_to_destroy_from_params(scope)
    choice = params[:destroy_round_choice].presence || "current"
    case choice
    when "current"
      scope.find_by(id: @round.id) || scope.last
    when "last"
      scope.last
    else
      return nil unless choice.to_s.match?(/\A\d+\z/)

      scope.find_by(id: choice.to_i)
    end
  end

  def score_winner_board(match)
    board0 = match.user_match_scores[0].is_winner ? match.user_match_scores[0] : match.user_match_scores[1]
    board1 = match.user_match_scores[1].is_winner ? match.user_match_scores[0] : match.user_match_scores[1]

    board = "#{board0.score_set1}-#{board1.score_set1} #{board0.score_set2}-#{board1.score_set2}"
    board += " #{board0.score_tiebreak}-#{board1.score_tiebreak}" if board0.score_tiebreak + board1.score_tiebreak > 0
    board
  end

  # Score string for doubles CSV: always team_a then team_b (same order as import assigns
  # match_scores[0] to team_a / CSV "team" side and match_scores[1] to team_b / "opponent").
  # Column name remains score_winner for backwards compatibility.
  def score_winner_from_team_scores(match)
    team_score_a = match.team_match_scores.find { |s| s.team_id == match.team_a_id }
    team_score_b = match.team_match_scores.find { |s| s.team_id == match.team_b_id }
    return nil unless team_score_a && team_score_b

    board0, board1 = team_score_a, team_score_b
    board = "#{board0.score_set1}-#{board1.score_set1} #{board0.score_set2}-#{board1.score_set2}"
    board += " #{board0.score_tiebreak}-#{board1.score_tiebreak}" if board0.score_tiebreak.to_i + board1.score_tiebreak.to_i > 0
    board
  end

  def score_csv_headers_for_round(round)
    if round.doubles_format?
      MatchesController::REQUIRED_DOUBLES_SCORES_HEADERS + MatchesController::OPTIONAL_DOUBLES_SCORES_HEADERS
    else
      MatchesController::REQUIRED_SCORES_HEADERS + MatchesController::OPTIONAL_SCORES_HEADERS
    end
  end

  def singles_score_csv_row(match)
    match_scores = match.user_match_scores.includes(:user).to_a
    return nil if match_scores.size < 2

    p0 = match_scores[0]
    p1 = match_scores[1]
    [
      p0.user.first_name, p0.user.last_name,
      p1.user.first_name, p1.user.last_name,
      p0.user.email, p1.user.email,
      match.box.box_number, score_winner_board(match),
      p0.user.phone_number, p1.user.phone_number, p0.user.role, p1.user.role,
      match.time, match.court&.name, p0.input_user_id, p0.input_date
    ]
  end

  def doubles_score_csv_row(match)
    team_a_players = ordered_team_players(match.team_a)
    team_b_players = ordered_team_players(match.team_b)
    score = score_winner_from_team_scores(match)
    return nil unless team_a_players.size >= 2 && team_b_players.size >= 2 && score.present?

    input_source = match.team_match_scores.find { |s| s.team_id == match.team_a_id } || match.team_match_scores.first
    [
      team_a_players[0].first_name, team_a_players[0].last_name,
      team_a_players[1].first_name, team_a_players[1].last_name,
      team_b_players[0].first_name, team_b_players[0].last_name,
      team_b_players[1].first_name, team_b_players[1].last_name,
      team_a_players[0].email, team_a_players[1].email, team_b_players[0].email, team_b_players[1].email,
      match.box.box_number, score,
      team_a_players[0].phone_number, team_a_players[1].phone_number,
      team_b_players[0].phone_number, team_b_players[1].phone_number,
      team_a_players[0].role, team_a_players[1].role, team_b_players[0].role, team_b_players[1].role,
      match.time, match.court&.name, input_source&.input_user_id, input_source&.input_date
    ]
  end

  def ordered_team_players(team)
    return [] unless team

    team.users.sort_by { |u| [u.last_name.to_s.upcase, u.first_name.to_s.upcase, u.id.to_i] }
  end

  def user_matches(user, box)
    # for a given user, selects match scores in box, and returns array of matches
    # user.user_match_scores.select { |user_match_score| user_match_score.match.box == box }.map(&:match)
    user.user_match_scores.includes([match: :box]).select { |user_match_score| user_match_score.match.box == box }.map(&:match)
  end

  def opponent(match, player)
    # for a given match, selects match score of other player, and returns other player
    match.user_match_scores.reject { |user_match_score| user_match_score.user == player }.map(&:user)[0]
  end

  def box_matches(box)
    # returns array of [user_box_score, matches_details, user] sorted by player's total points
    # where matches_details is an array of [match, opponent, user_score, opponent_score]
    return box_team_matches(box) if box.round.doubles_format?

    box_matches = []
    # box.user_box_scores.each do |user_box_score|
    # box.user_box_scores.includes([user: {user_match_scores: :match}]).each do |user_box_score|
    box.user_box_scores.includes([:user]).each do |user_box_score|
      box_matches << [user_box_score, matches_details(user_box_score), user_box_score.user]
    end
    box_matches.sort { |a, b| b[0].points <=> a[0].points } # sorts by descending points scores
  end

  def box_team_matches(box)
    team_matches = []
    box.teams.includes(:users).each do |team|
      tbs = TeamBoxScore.find_by(team_id: team.id, box_id: box.id)
      team_matches << [tbs, team_matches_details(team, box), team]
    end
    team_matches.sort { |a, b| (b[0]&.points || 0) <=> (a[0]&.points || 0) }
  end

  def matches_details(user_box_score)
    # returns array of [match, opponent, user_score, opponent_score]
    user = user_box_score.user
    matches = user_matches(user, user_box_score.box)
    matches.map! do |match|
      opponent = opponent(match, user)
      [match, opponent, match_score(match, user), match_score(match, opponent)]
    end
    matches << [nil, user, nil, nil] # add user to the list
  end

  def team_matches_details(team, box)
    matches = team_matches(team, box)
    matches = matches.map do |match|
      opponent_team = team_opponent(match, team)
      [match, opponent_team, team_match_score(match, team), team_match_score(match, opponent_team)]
    end
    matches << [nil, team, nil, nil] # add team to align with grid/list loops
  end

  def team_matches(team, box)
    Match.where(box_id: box.id).where("team_a_id = ? OR team_b_id = ?", team.id, team.id)
  end

  def team_opponent(match, team)
    match.team_a_id == team.id ? match.team_b : match.team_a
  end

  def team_match_score(match, team)
    TeamMatchScore.find_by(match_id: match.id, team_id: team.id)
  end
end

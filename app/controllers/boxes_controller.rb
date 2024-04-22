class BoxesController < ApplicationController
  require "csv"
  helper_method :box_matches, :my_box?  # allows the #box_matches method to be called from views
  DAYS_BEFORE_NEW_ROUND_CREATION = 15
  PLAYERS_HEADERS = ["id", "club_id", "email", "first_name", "last_name", "nickname", "phone_number", "role", "box_number"]
  SCORES_HEADERS = ["first_name_player", "last_name_player",
                    "first_name_opponent", "last_name_opponent",
                    "points_player", "points_opponent",
                    "box_number", "score_winner", "score_winner2"]
  SCORES_HEADERS_PLUS = ["email_player", "phone_number_player", "role_player",
                    "email_opponent", "phone_number_opponent", "role_opponent",
                    "match_date", "court_nb", "input_user_id", "input_date"]

  def index
    # display all boxes and the shared select_round form
    @page_from = params[:page_from]
    set_club_round # set variables @club, @round and @boxes (ApplicationController)
    # @my_box = 0
    # @boxes&.each { |box| @my_box = box if my_box?(box) } # Ruby Safe Navigation (instead of if @boxes each_block else nil end)
    @my_box = my_own_box(@round)
    if @round
      init_stats
      days_left = (@round.end_date - Date.today).to_i # nb of days til then end of the round
      # admin : create button appears in last days or after if round is the most recent
      @new_round_required = (days_left <= DAYS_BEFORE_NEW_ROUND_CREATION) && (round_dropdown_to_start_date(@rounds_dropdown.first) == @round.start_date)
      # referee : request button appears only before end of the last round
      @new_round_request = days_left.positive? && @new_round_required
    end
  end

  def index_expanded
    index
  end

  def show
    # display one box in table view, links to view and edit match cards
    unless params[:id].to_i.zero?
      @page_from = params[:page_from]
      @box = Box.find(params[:id])
      @round = @box.round
      @my_box = my_own_box(@round)
      init_stats
      @round_nb = round_label(@round)
      # @box_matches is an array of [user_box_score , matches_details(user), user]
      # matches_details(user) is an array of [match, opponent, user_score, opponent_score]
      @box_matches = box_matches(@box) # sorted by descending points scores
      @is_this_my_box = my_box?(@box)
    end
  end

  def show_list
    # display one box in list view, links to view and edit match cards
    show # inherit from #show
  end

  def my_scores
    # player: view their box and select enter new score / view played match
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
      @my_matches = []
      @box.user_box_scores.each do |user_box_score|
        opponent_matches = user_matches(user_box_score.user, @box)
        current_player_matches = user_matches(@current_player, @box)
        match_played = (opponent_matches & current_player_matches)[0]
        @my_matches << [user_box_score, match_played]
      end
      @my_matches = @my_matches.sort { |a, b| b[0].points <=> a[0].points }
      if !@box.chatroom || @box.chatroom == @general_chatroom
        # create here (open) a new chatroom if it does not exist yet or if it is still set to "general":
        # rationale : the Chatroom class was migrated after the Box class (with: chatroom has one box)
        # and the migration script assigned the #general chatroom by default to existing boxes.
        # The name format: "[Club name] - R[Round id]:B[Box number]"
        # a chatroom is box and round specific:
        # players can access it when visiting My Scores or from the navbar menu Chatrooms
        @chatroom = Chatroom.create(name: chatroom_name(@box))
        @box.update(chatroom_id: @chatroom.id)
      else
        @chatroom = @box.chatroom
      end
    end
  end

  def round_boxes_to_csv
    # export for the selected round a list of players and the referee to a csv file
    # credits https://www.freecodecamp.org/news/export-a-database-table-to-csv-using-a-simple-ruby-script-2/
    round = Round.find(params[:round_id])
    # file = Rails.root.join('public', 'data.csv')
    file = "#{Rails.root}/public/data.csv"
    boxes = round.boxes.includes([:user_box_scores]).sort { |a, b| a.box_number <=> b.box_number }
    user_box_scores = boxes.map(&:user_box_scores).flatten;0 # ";0" stops output.
    # 'referee' or 'player referee' : User.find_by("club_id = ? AND role like ?", round.club_id, "%referee%")
    referee = User.find_by(role: "referee", club_id: round.club_id) #only 'referee', not 'player referee'
    CSV.open(file, 'w') do |writer|
      # table headers
      # PLAYERS_HEADERS = ["id", "club_id", "email", "first_name", "last_name", "nickname", "phone_number", "role", "box_number"]
      writer << PLAYERS_HEADERS
      user_box_scores.each_with_index do |ubs, index|
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
    download_csv(file.pathmap, "Boxes-R#{round_label(round)}", round.club.name)
  end

  def round_scores_to_csv
    # export for the selected round the scores to a csv file
    # complying with the expected format for matches#create_scores
    # credits https://www.freecodecamp.org/news/export-a-database-table-to-csv-using-a-simple-ruby-script-2/
    round = Round.find(params[:round_id])
    referee = User.find_by("club_id = ? AND role like ?", round.club_id, "%referee%")
    # file = Rails.root.join('public', 'data.csv')
    file = "#{Rails.root}/public/data.csv"
    boxes = round.boxes.includes([user_box_scores: :user, matches: :user_match_scores])
    user_box_scores = boxes.map(&:user_box_scores).flatten;0 # ";0" stops output.
    matches = boxes.map(&:matches).flatten;0 # ";0" stops output.
    CSV.open(file, 'w') do |writer|
      # table headers
      # SCORES_HEADERS = ["first_name_player", "last_name_player",
      #                   "first_name_opponent", "last_name_opponent",
      #                   "points_player", "points_opponent",
      #                   "box_number", "score_winner", "score_winner2"]
      # REQUIRED_SCORE_HEADERS_PLUS = ["email_player", "phone_number_player", "role_player",
      #                    "email_opponent", "phone_number_opponent", "role_opponent",
      #                    "match_date", "court_nb", "input_user_id", "input_date"]
      writer << SCORES_HEADERS + SCORES_HEADERS_PLUS
      matches.each_with_index do |match, index|
        match_scores = match.user_match_scores
        writer << [match_scores[0].user.first_name, match_scores[0].user.last_name,
                   match_scores[1].user.first_name, match_scores[1].user.last_name,
                   match_scores[0].points, match_scores[1].points,
                   match.box.box_number, score_winner_board(match), score_winner_board(match),
                   match_scores[0].user.email, match_scores[0].user.phone_number, match_scores[0].user.role,
                   match_scores[1].user.email, match_scores[1].user.phone_number, match_scores[1].user.role,
                   match.time, match.court.name, match_scores[0].input_user_id, match_scores[0].input_date]
      end
    end
    download_csv(file.pathmap, "Scores-R#{round_label(round)}", round.club.name)
  end

  private

  def score_winner_board(match)
    board0 = match.user_match_scores[0].is_winner ? match.user_match_scores[0] : match.user_match_scores[1]
    board1 = match.user_match_scores[1].is_winner ? match.user_match_scores[0] : match.user_match_scores[1]

    board = "#{board0.score_set1}-#{board1.score_set1} #{board0.score_set2}-#{board1.score_set2}"
    board += " #{board0.score_tiebreak}-#{board1.score_tiebreak}" if board0.score_tiebreak + board1.score_tiebreak > 0
    board
  end

  def user_matches(user, box)
    # for a given user, select match scores in box, and returns array of matches
    # user.user_match_scores.select { |user_match_score| user_match_score.match.box == box }.map(&:match)
    user.user_match_scores.includes([match: :box]).select { |user_match_score| user_match_score.match.box == box }.map(&:match)
  end

  def opponent(match, player)
    # for a given match, select match score of other player, and returns other player
    match.user_match_scores.reject { |user_match_score| user_match_score.user == player }.map(&:user)[0]
  end

  def box_matches(box)
    # return array of [user_box_score, matches_details, user] sorted by player's total points
    # where matches_details is an array of [match, opponent, user_score, opponent_score]
    box_matches = []
    # box.user_box_scores.each do |user_box_score|
    # box.user_box_scores.includes([user: {user_match_scores: :match}]).each do |user_box_score|
    box.user_box_scores.includes([:user]).each do |user_box_score|
      box_matches << [user_box_score, matches_details(user_box_score), user_box_score.user]
    end
    box_matches.sort { |a, b| b[0].points <=> a[0].points } # sorts by descending points scores
  end

  def matches_details(user_box_score)
    # return array of [match, opponent, user_score, opponent_score]
    user = user_box_score.user
    matches = user_matches(user, user_box_score.box)
    matches.map! do |match|
      opponent = opponent(match, user)
      [match, opponent, match_score(match, user), match_score(match, opponent)]
    end
    matches << [nil, user, nil, nil] # add user to the list
  end
end

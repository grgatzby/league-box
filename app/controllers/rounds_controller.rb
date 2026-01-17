# Rounds Controller
# Handles round creation, editing, and player promotion/relegation.
# Allows admin to create new rounds from CSV files or form-based player moves.
# Manages player movement between boxes based on performance (promotion/relegation).
class RoundsController < ApplicationController
  MIN_QUALIFYING_MATCHES = 0 #2 # Minimum matches required to qualify for next round (currently 0)
  MIN_PLAYERS_PER_BOX = 4
  NEW_ROUND_HEADERS = ["email", "first_name", "last_name", "phone_number", "role"].sort
  REFEREE = ["referee", "player referee"]
  PLAYERS = ["player", "player referee"]
  PLAYERS_AND_SPARES = PLAYERS + ["spare"]

  # Display form to create a new round (referees/admin only)
  # Pre-populates form with suggested player moves based on current round rankings:
  #   - Top 2 players: promoted (1st: 2 boxes up, 2nd: 1 box up)
  #   - Bottom 2 players: relegated (last: 2 boxes down, 2nd last: 1 box down)
  #   - Players with < MIN_QUALIFYING_MATCHES: removed (move = 99)
  # Can also create round from CSV file upload
  def new
    @current_round = current_round(params[:club_id] ? params[:club_id].to_i : current_user.club_id)
    @boxes = @current_round.boxes.sort

    @new_round = Round.new
    # the rounds/new.html.erb form accepts nested attributes for boxes and user_box_scores
    @player_moves = []
    @boxes.each do |box|
      new_box = @new_round.boxes.build
      user_box_scores = box.user_box_scores.sort { |a, b| a.rank <=> b.rank }
      box_player_move = Hash.new(0)
      # In normal circumstances, for each box:
      # - the top two players will be promoted (first player: 2 boxes, second: 1 box)
      box_player_move[0] = box.box_number == 1 ? 0 : (box.box_number == 2 ? 1 : 2)
      box_player_move[1] = box.box_number == 1 ? 0 : 1
      # - the last two players will be relegated (last player: 2 boxes, second last: 1 box)
      box_player_move[user_box_scores.length - 2] = box.box_number == @boxes.length ? 0 : -1
      box_player_move[user_box_scores.length - 1] = box.box_number == @boxes.length ? 0 : (box.box_number == @boxes.length - 1 ? -1 : -2)
      # - A player who has played less than two matches (MIN_QUALIFYING_MATCHES) will be removed from the league.
      user_box_scores.each_with_index do |ubs, index|
        new_box.user_box_scores.build # one nested attribute per player for building the form
        # array of proposed moves for each player in the round : 1 up, 0 stay, -1 down, 99 = remove from next round
        @player_moves << (ubs.matches_played >= MIN_QUALIFYING_MATCHES ? box_player_move[index] : 99)
      end
    end
  end

  # Create a new round (admin only)
  # Two modes:
  #   1. CSV file upload: Creates round with players from CSV (with or without box_number)
  #   2. Form submission: Creates round using player moves from current round (promotion/relegation)
  # New boxes are assigned to #general chatroom initially (replaced when player visits My Scores)
  def create

    csv_file = params[:round][:csv_file]
    delimiter = params[:delimiter]
    if csv_file && csv_file.content_type == "text/csv"
      # a CSV file is attached, create new round using it
      headers = CSV.foreach(csv_file, col_sep: delimiter).first
      if headers.compact.map(&:downcase).sort - ["box_number"] == NEW_ROUND_HEADERS
        club = Club.find(params[:club_id])
        box_players = [] # array (one per box) of array of box players
        boxes = [] # array of boxes
        # estimate the nb of players of the current box as current box 1's nb of players
        players_per_box = club.rounds.last.boxes.find_by(box_number: 1).user_box_scores.size
        # create new round
        round = Round.create(club_id: params[:club_id],
                             start_date: params[:round][:start_date].to_date,
                             end_date: params[:round][:end_date].to_date,
                             league_start: params[:round][:league_start].to_date)

        # array of users (players and club referees)
        users = []
        box_numbers = []
        nb_spare = 0
        CSV.foreach(csv_file, headers: :first_row, header_converters: :symbol, col_sep: delimiter) do |row|
          # test if user already created, if not, create user
          if PLAYERS_AND_SPARES.include?(row[:role])
            if row[:box_number]
              if User.exists?(first_name: row[:first_name], last_name: row[:last_name])
                user = User.find_by(first_name: row[:first_name], last_name: row[:last_name])
              else
                if row[:role].downcase == "spare"
                  nb_spare += 1
                  email = "spare#{format('%02d', nb_spare)}@club.com"
                else
                  email = row[:email]
                end
                user = User.create(email:,
                                   first_name: row[:first_name], last_name: row[:last_name],
                                   phone_number: row[:phone_number], role: row[:role].downcase)

              end
              box_numbers << row[:box_number].to_i
              # if user.role == "player" || user.role == "player referee" || user.role == "spare"
              if PLAYERS_AND_SPARES.include?(user.role)
                if box_players[row[:box_number].to_i]
                  box_players[row[:box_number].to_i] << user
                else
                  box_players[row[:box_number].to_i] = [user]
                end
              end
            else
              user = User.create(row)
            end

            user.update(club_id: params[:club_id], password: "123456", nickname: user.nickname || (user.first_name + user.last_name[0]))
            # user.update(password: "654321") if user.role == "referee" || user.role == "player referee"
            user.update(password: "654321") if REFEREE.include?(user.role)
            users << user
          end
        end

        # players = users.select { |user| user.role == "player" || user.role == "player referee" }
        players = users.select { |user| PLAYERS.include?(user.role) }

        # create boxes and user_box_scores
        if headers.include?("box_number")
          box_numbers = box_numbers.uniq.sort
          nb_boxes = box_numbers.size
          nb_boxes.times do |box_index|
            boxes << Box.create(round_id: round.id, box_number: box_numbers[box_index],
                                chatroom_id: @general_chatroom.id)

            box_players[box_numbers[box_index]].each do |player|
              UserBoxScore.create(user_id: player.id, box_id: boxes[box_index].id,
                                  points: 0, rank: 1,
                                  sets_won: 0, sets_played: 0,
                                  matches_won: 0, matches_played: 0,
                                  games_won: 0, games_played: 0)
            end
          end
          players_per_box = box_players[1].size
        else
          players_per_box = params[:players_per_box].to_i
          # if players_per_box > MIN_PLAYERS_PER_BOX, adjust down players_per_box so there are no less than 4 players per box
          players_per_box -= 1 while (players.size % players_per_box < MIN_PLAYERS_PER_BOX) && players_per_box > MIN_PLAYERS_PER_BOX
          nb_boxes = (players.size / players_per_box) + ((players.size % players_per_box) > MIN_PLAYERS_PER_BOX - 1 ? 1 : 0)
          nb_boxes.times do |box_index|
            # TO DO: create a new chatroom for the box
            boxes << Box.create(round_id: round.id, box_number: box_index + 1, chatroom_id: @general_chatroom.id)
            box_players << players.shift(players_per_box) # adds one array of box players
            box_players[box_index].each do |player|
              UserBoxScore.create(user_id: player.id, box_id: boxes[box_index].id,
                                  points: 0, rank: 1,
                                  sets_won: 0, sets_played: 0,
                                  matches_won: 0, matches_played: 0,
                                  games_won: 0, games_played: 0)
            end
          end
        end
        # # if players_per_box > MIN_PLAYERS_PER_BOX, adjust down players_per_box so there are no less than 4 players per box
        # if (players.size % players_per_box).positive?
        #   players_per_box -= 1 while (players.size % players_per_box < MIN_PLAYERS_PER_BOX) && players_per_box > MIN_PLAYERS_PER_BOX
        # end
        # nb_boxes = (players.size / players_per_box) + ((players.size % players_per_box) > MIN_PLAYERS_PER_BOX - 1 ? 1 : 0)
        # box_players = []
        # boxes = []
        # nb_boxes.times do |box_index|
        #   # TO DO: create a new chatroom for each new box
        #   boxes << Box.create(round_id: round.id, box_number: box_index + 1, chatroom_id: @general_chatroom.id)
        #   box_players << players.shift(players_per_box)
        #   box_players[box_index].each do |player|
        #     UserBoxScore.create(user_id: player.id, box_id: boxes[box_index].id,
        #                         points: 0, rank: 1,
        #                         sets_won: 0, sets_played: 0,
        #                         matches_won: 0, matches_played: 0,
        #                         games_won: 0, games_played: 0)
        #   end
        # end
        flash[:notice] = t('.round_created', count: players.size % players_per_box, players: players_per_box)
        if (players.size % players_per_box).positive? && box_numbers.empty?
          players.each(&:destroy) # destroy all remaining players (when less than MIN_PLAYERS_PER_BOX are left)
        end
        redirect_to boxes_path(round_id: round.id, club_id: club.id)
      else
        flash[:notice] = t('.header_flash')
        redirect_back(fallback_location: new_user_box_score_path)
      end
    else
      # no CSV file is attached, create new round using the form shifts
      current_round = current_round(params[:club_id] ? params[:club_id].to_i : current_user.club_id)

      @new_round = Round.create(club_id: current_round.club_id,
                                start_date: params[:round][:start_date].to_date,
                                end_date: params[:round][:end_date].to_date,
                                league_start: params[:round][:league_start].to_date)

      current_boxes = current_round.boxes.sort_by(&:box_number)
      temp_boxes = new_temp_boxes(current_boxes.size) # array of temporary boxes; as many as current_boxes'
      apply_shifts(current_boxes, temp_boxes) # shift current_boxes' players within temp_boxes using the form shifts

      nb_players_per_box = current_boxes[0].user_box_score_ids.length
      clean_boxes(temp_boxes, nb_players_per_box)

      redirect_to boxes_path(round_id: @new_round.id, club_id: current_round.club_id)
    end
  end

  # Display form to edit round end_date (admin and referee only)
  # Only allows editing the most recent round's end_date
  # Validates that no matches were played after the new end_date
  def edit
    data = Club.all.includes(rounds: :boxes).as_json(
      include: { rounds: { only: [:id, :start_date, :end_date, :league_start] } })
    # transform the hash format convention {"round" => value} to {round: value} and exclude the sample club
    data.each(&:deep_symbolize_keys!).reject! { |a| a[:id] == @sample_club.id }
    @clubs = data.map { |club| club[:name] }
    params[:club] = current_user.club.name if REFEREE.include?(current_user.role)
    if params[:club]
      club_index = data.index { |club| club[:name] == params[:club] }
      club_id = Club.find_by(name: params[:club]).id
      rounds = data[club_index][:rounds].map { |round| [round[:league_start], round[:start_date]] }.sort
      # pick the last round in the most recent tournament
      @round = Round.find_by(start_date: rounds.last[1], club_id:)
      @last_round_match_date = last_round_match_date(@round)
    end
  end

  # Update round end_date (admin and referee only)
  # Validates that no matches were played after the proposed new end_date
  def update
    @round = Round.find(params[:id])
    # Validation: prevent changing end_date if matches were played after proposed date
    if last_round_match_date(@round) > params[:round][:end_date].to_date
      flash[:alert] = "Some match have been played beyond the proposed end date" # Match
      render :edit, status: :unprocessable_entity
    else
      @round.update(round_params)
      redirect_to boxes_path(round_id: @round.id, club_id: @round.club_id)
    end
  end

  private

  # Create temporary boxes for new round (same number as current round)
  # Temporary boxes will be cleaned and redistributed in #clean_boxes
  # All boxes initially assigned to #general chatroom
  def new_temp_boxes(nb_boxes)
    boxes = []
    nb_boxes.times do |box_index|
      boxes << Box.create(round_id: @new_round.id, box_number: box_index + 1, chatroom_id: @general_chatroom.id)
    end
    boxes
  end

  # Apply player moves (promotion/relegation) to temporary boxes
  # Moves players based on form input (shift values: 2, 1, 0, -1, -2, 99)
  # Players not evenly distributed yet (handled in #clean_boxes)
  def apply_shifts(current_boxes, new_boxes)
    current_boxes.size.times do |box_index|
      nb_players = current_boxes[box_index].user_box_score_ids.size
      nb_players.times do |player_index|
        player_shift = params[:round][:boxes_attributes][box_index.to_s][:user_box_scores_attributes][player_index.to_s][:box_id].to_i
        user_box_scores = current_boxes[box_index].user_box_scores.sort { |a, b| a.rank <=> b.rank }
        player_id = user_box_scores[player_index].user_id
        UserBoxScore.create(
          user_id: player_id,
          box_id: new_boxes[box_index - player_shift].id,
          points: 0, rank: 0,
          sets_won: 0, sets_played: 0,
          matches_won: 0, matches_played: 0,
          games_won: 0, games_played: 0
        ) unless player_shift == 99
      end
    end
  end

  # Redistribute players evenly across boxes and delete empty boxes
  # Groups players into equal-sized boxes (nb_player_per_box per box)
  # Remaining empty boxes are deleted
  def clean_boxes(temp_boxes, nb_player_per_box)
    all_user_box_scores = temp_boxes.map(&:user_box_scores).flatten
    # create groups of user_box_scores items (nb_player_per_box items per group)
    nb_new_boxes = all_user_box_scores.size / nb_player_per_box
    new_user_box_score_groups = []
    # shift(n) is an Array method: removes first n element from array and returns the array of these n elements
    nb_new_boxes.times { new_user_box_score_groups << all_user_box_scores.shift(nb_player_per_box) }
    new_user_box_score_groups << all_user_box_scores unless all_user_box_scores.empty? # || all_user_box_scores.size < min_player_per_box
    nb_new_boxes = new_user_box_score_groups.size

    # for each new group of user_box_scores, update field box_id
    new_user_box_score_groups.each_with_index do |user_box_scores, index|
      user_box_scores.each { |user_box_score| user_box_score.update(box_id: temp_boxes[index].id) }
    end

    # delete remaining empty boxes (not destroy because dependent destroy still links updated user_box_scores)
    # shift(n) is an Array method: removes first n element from array and returns the array of these n elements
    temp_boxes.shift(nb_new_boxes) # remove populated boxes from temp_boxes array
    temp_boxes.each(&:delete)
  end

  private

  # Strong parameters for round updates
  def round_params
    params.require(:round).permit(:end_date)
  end
end

class RoundsController < ApplicationController
  MIN_QUALIFYING_MATCHES = 2
  MIN_PLAYERS_PER_BOX = 4
  REQUIRED_HEADERS = ["id", "club_id", "email", "first_name", "last_name", "phone_number", "role"].sort

  def new
    # called from a button in Boxes index view (referees only)
    # form request to admin to generate a next round derived from the current
    # There is a file upload field in the form so the admin can create the round from a CSV file
    # if admin is logged in, the club is given by params[:club_id]
    @current_round = current_round(params[:club_id] ? params[:club_id].to_i : current_user.club_id)
    @boxes = @current_round.boxes.sort

    @new_round = Round.new
    # the rounds/new.html.erb form accepts nested attributes for boxes and user_box_scores
    @player_moves = []
    @boxes.each do |box|
      new_box = @new_round.boxes.build
      user_box_scores = box.user_box_scores.sort { |a, b| a.rank <=> b.rank }
      box_player_move = Hash.new(0)
      # In normal circumstances:
      # - the top two players will be promoted 1 box, unless in box 1 already
      box_player_move[0] = box.box_number == 1 ? 0 : 1
      box_player_move[1] = box.box_number == 1 ? 0 : 1
      # - the last two players will be relegated 1 box, unless in last box already
      box_player_move[user_box_scores.length - 2] = box.box_number == @boxes.length ? 0 : -1
      box_player_move[user_box_scores.length - 1] = box.box_number == @boxes.length ? 0 : -1
      # - A player who has played less than two matches (MIN_QUALIFYING_MATCHES) will be removed from the league.
      user_box_scores.each_with_index do |ubs, index|
        new_box.user_box_scores.build # one nested attribute per player for building the form
        # array of proposed moves for each player in the round : 1 up, 0 stay, -1 down, 99 = remove from next round
        @player_moves << (ubs.matches_played >= MIN_QUALIFYING_MATCHES ? box_player_move[index] : 99)
      end
    end
  end

  def create
    # admin or referee to generate next round from the current one
    # if user is admin, club is given by params[:club_id], else: the referee's club
    # the new round is seeded through the uploaded CSV file or if none, through the form
    # TO DO: create a chatroom for each new box:
    # maybe dealt with in the 20231018223106_add_reference_to_boxes migration file with the default value

    csv_file = params[:round][:csv_file]
    if csv_file.content_type == "text/csv"
      # a CSV file is attached, create new round using it
      headers = CSV.foreach(csv_file).first
      if headers.sort - ["nickname"] == REQUIRED_HEADERS
        club = Club.find(params[:club_id])
        # estimate the nb of players of the current box as current box 1's nb of players
        players_per_box = club.rounds.last.boxes.find_by(box_number:1).user_box_scores.count
        # create new round
        round = Round.create(start_date: params[:round][:start_date].to_date, end_date: params[:round][:end_date].to_date, club_id: params[:club_id])

        # array of users (players and club referees)
        users = []
        CSV.foreach(csv_file, headers: :first_row, header_converters: :symbol) do |row|
          # test if user already created, if not, create user
          if User.exists?(row[:id])
            user = User.find(row[:id])
          else
            user = User.create(row)
            user.update(club_id: params[:club_id], password: "123456", nickname: user.nickname || (user.first_name + user.last_name[0]))
            user.update(password: "654321") if user.role == "referee"
          end
          users << user
        end

        players = users.select { |user| user.role == "player" }

        # create boxes and user_box_scores
        # if players_per_box > MIN_PLAYERS_PER_BOX, adjust down players_per_box so there are no less than 4 players per box
        if (players.count % players_per_box).positive?
          players_per_box -= 1 while (players.count % players_per_box < MIN_PLAYERS_PER_BOX) && players_per_box > MIN_PLAYERS_PER_BOX
        end
        nb_boxes = (players.count / players_per_box) + ((players.count % players_per_box) > MIN_PLAYERS_PER_BOX - 1 ? 1 : 0)
        box_players = []
        boxes = []
        nb_boxes.times do |box_index|
          # TO DO: create a new chatroom for each new box
          boxes << Box.create(round_id: round.id, box_number: box_index + 1, chatroom_id: @general_chatroom.id)
          box_players << players.shift(players_per_box)
          box_players[box_index].each do |player|
            UserBoxScore.create(user_id: player.id, box_id: boxes[box_index].id,
                                points: 0, rank: 1,
                                sets_won: 0, sets_played: 0,
                                matches_won: 0, matches_played: 0,
                                games_won: 0, games_played: 0)
          end
        end
        flash[:notice] = t('.round_created', count: players.count % players_per_box, players: players_per_box)
        if (players.count % players_per_box).positive?
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
                                start_date: params[:round][:start_date].to_date, end_date: params[:round][:end_date].to_date)

      current_boxes = current_round.boxes.sort_by(&:box_number)
      temp_boxes = new_temp_boxes(current_boxes.count) # array of temporary boxes; as many as current_boxes'
      apply_shifts(current_boxes, temp_boxes) # shift current_boxes' players within temp_boxes using the form shifts

      nb_players_per_box = current_boxes[0].user_box_score_ids.length
      clean_boxes(temp_boxes, nb_players_per_box)

      redirect_to boxes_path(round_id: @new_round.id, club_id: current_round.club.id)
    end
  end


  private

  def new_temp_boxes(nb_boxes)
    # return array of temporary boxes; nb_boxes = number of boxes in the current round
    # #general chatroom is assigned (automatically replaced when visiting My scores page)
    boxes = []
    nb_boxes.times do |box_index|
      boxes << Box.create(round_id: @new_round.id, box_number: box_index + 1, chatroom_id: @general_chatroom.id)
    end
    boxes
  end

  def apply_shifts(current_boxes, new_boxes)
    # assign players to temporary boxes according to requested box shift
    # players are not spread evenly accross boxes yet
    current_boxes.count.times do |box_index|
      nb_players = current_boxes[box_index].user_box_score_ids.count
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

  def clean_boxes(temp_boxes, nb_player_per_box)
    # deal players (user_box_scores) evenly across temporary boxes and delete remaining empty boxes
    all_user_box_scores = temp_boxes.map(&:user_box_scores).flatten
    # create groups of user_box_scores items (nb_player_per_box items per group)
    nb_new_boxes = all_user_box_scores.count / nb_player_per_box
    new_user_box_score_groups = []
    # shift(n) is an Array method: removes first n element from array and returns the array of these n elements
    nb_new_boxes.times { new_user_box_score_groups << all_user_box_scores.shift(nb_player_per_box) }
    new_user_box_score_groups << all_user_box_scores unless all_user_box_scores.empty? # || all_user_box_scores.count < min_player_per_box
    nb_new_boxes = new_user_box_score_groups.count

    # for each new group of user_box_scores, update field box_id
    new_user_box_score_groups.each_with_index do |user_box_scores, index|
      user_box_scores.each { |user_box_score| user_box_score.update(box_id: temp_boxes[index].id) }
    end

    # delete remaining empty boxes (not destroy because dependent destroy still links updated user_box_scores)
    # shift(n) is an Array method: removes first n element from array and returns the array of these n elements
    temp_boxes.shift(nb_new_boxes) # remove populated boxes from temp_boxes array
    temp_boxes.each(&:delete)
  end
end

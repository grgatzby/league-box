class RoundsController < ApplicationController
  def new
    # invoked from a button in Boxes index view
    # form request to admin to generate a next round derived from the current
    # if admin is logged in, the club is given by params[:club_id]
    @current_round = current_round(params[:club_id] ? params[:club_id].to_i : current_user.club_id)
    @boxes = @current_round.boxes.sort

    @new_round = Round.new
    # the rounds/new.html.erb form accepts nested attributes for boxes and user_box_scores
    @player_moves = []
    @boxes.each do |box|
      new_box = @new_round.boxes.build
      user_box_scores = box.user_box_scores.sort { |a, b| a.rank <=> b.rank }
      # In normal circumstances
      # - the top two players will be promoted 1 box,
      # - the last two players will be relegated 1 box,
      # A player who has played less than two matches will be removed from the league.
      min_qualifying_games = 2
      box_player_move = Hash.new(0)
      box_player_move[0] = box.box_number == 1 ? 0 : 1
      box_player_move[1] = box.box_number == 1 ? 0 : 1
      box_player_move[user_box_scores.length - 2] = box.box_number == @boxes.length ? 0 : -1
      box_player_move[user_box_scores.length - 1] = box.box_number == @boxes.length ? 0 : -1
      user_box_scores.each_with_index do |ubs, index|
        new_box.user_box_scores.build # one nested attribute per player for the form
        # array of proposed moves for each player in the round (99 = player removed from next round)
        @player_moves << (ubs.games_played >= min_qualifying_games ? box_player_move[index] : 99)
      end
    end
  end

  def create
    # admin or referee to generate next round from current
    # if admin logged in, club given by params[:club_id]
    # TO DO: create a chatroom for each new box:
    # maybe dealt with in the 20231018223106_add_reference_to_boxes migration file with the default value
    current_round = current_round(params[:club_id] ? params[:club_id].to_i : current_user.club_id)

    @new_round = Round.create(club_id: current_round.club_id,
                              start_date: params[:round][:start_date].to_date,
                              end_date: params[:round][:end_date].to_date)

    current_boxes = current_round.boxes
    temp_boxes = new_temp_boxes(current_boxes.count)
    apply_shifts(current_boxes, temp_boxes)

    clean_boxes(temp_boxes, current_boxes[0].user_box_score_ids.length)

    # redirect to boxes/index
    redirect_to boxes_path(round_start: @new_round.start_date, club_name: current_round.club.name)
  end

  private

  def new_temp_boxes(nb_boxes)
    # return array of temporary boxes; nb_boxes : number of boxes in the current round
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
          points: 0,
          rank: 0,
          sets_won: 0,
          sets_played: 0,
          games_won: 0,
          games_played: 0
        ) unless player_shift == 99
      end
    end
  end

  def clean_boxes(temp_boxes, nb_player_per_box)
    # deal players (user_box_scores) evenly across temporary boxes and delete remaining empty boxes

    all_user_box_scores = temp_boxes.map(&:user_box_scores).flatten
    # create groups of user_box_scores (nb_player_per_box items per group)
    new_user_box_score_groups = []
    nb_new_boxes = all_user_box_scores.count / nb_player_per_box
    # shift(n) is an Array method: removes first n element from array and returns the array of these n elements
    nb_new_boxes.times { new_user_box_score_groups << all_user_box_scores.shift(nb_player_per_box) }
    new_user_box_score_groups << all_user_box_scores unless all_user_box_scores.empty?
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

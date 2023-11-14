class BoxesController < ApplicationController
  def index
    @page_from = params[:page_from]
    set_club_round    # define variables @club and @round
  end

  def show
    @page_from = params[:page_from]
    @box = Box.find(params[:id])
    # @box_matches: array of [user_box_score , matches(user_box_score.user)]
    # matches(user_box_score.user): array of [match, opponent, user_score, opponent_score]
    @box_matches = box_matches(@box)
    @this_is_my_box = my_box?(@box)
    @my_current_box = my_own_box(current_round(current_user.club_id))
  end

  def show_list
    show        # inherits from #show method
  end

  def show_referee
    show        # inherits from #show method
  end

  def my_box
    @page_from = params[:page_from]
    @current_player = current_user
    # allows player to view their box and select enter new score / view played match
    if params[:id].to_i.zero?
      set_club_round # define variables @club and @round
      # @box = current_user.user_box_scores.map { |ubs| ubs.box }.select { |box| box.round == @round }[0]
      @box = my_own_box(@round, @current_player) # gets my box from chosen round
      @user_not_in_round = true unless @box
    else
      @box = Box.find(params[:id])
    end
    if @box
      @my_games = []
      @box.user_box_scores.each do |user_box_score|
        opponent_matches = user_matches(user_box_score.user, @box)
        current_player_matches = user_matches(@current_player, @box)
        match_played = (opponent_matches & current_player_matches)[0]
        @my_games << [user_box_score, match_played]
      end
      @my_games = @my_games.sort { |a, b| b[0].points <=> a[0].points }

      if !@box.chatroom || @box.chatroom == @general_chatroom
        # the Chatroom class was migrated after the Box class (with: a chatroom has one box)
        # and the migration script assigned the #general chatroom to existing boxes by default
        # if the assigned chatroom is still #general, or if this box has no chatroom,
        # create here a new chatroom here whith the name: "[Club name] - b[Box number]/R[Round id]"
        # it will NOT remain available to players when in the next round (chatroom is round specific)
        @chatroom = Chatroom.create(name: "#{@box.round.club.name} - B#{format('%02d', @box.box_number)}/R#{format('%02d', @box.round.id)}")
        @box.update(chatroom_id: @chatroom.id)
      else
        @chatroom = @box.chatroom
      end
    end
  end

  private

  def user_matches(user, box)
    # for given user, selects match scores in box, and returns array of matches
    user.user_match_scores.select { |user_match_score| user_match_score.match.box == box }.map(&:match)
  end

  def opponent(match, player)
    # for given match selects match score of other player, and returns other player
    match.user_match_scores.reject { |user_match_score| user_match_score.user == player }.map(&:user)[0]
  end

  def box_matches(box)
    # returns array of [user_box_score, matches_details, user] sorted by player's total points
    box_matches = []
    box.user_box_scores.each do |user_box_score|
      box_matches << [user_box_score, matches_details(user_box_score), user_box_score.user]
    end
    box_matches.sort { |a, b| b[0].points <=> a[0].points } # sorts by descending points scores
  end

  def matches_details(user_box_score)
    user = user_box_score.user
    matches = user_matches(user, user_box_score.box)
    matches.map! do |match|
      opponent = opponent(match, user)
      [match, opponent, match_score(match, user), match_score(match, opponent)]
    end
    matches << [nil, user, nil, nil] # adds user to the list
  end

  def my_box?(box, player = current_user)
    # returns true if player belongs to box, false if not
    box.user_box_scores.map(&:user).select { |user| user == player }.size.positive?
  end
end

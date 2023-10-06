class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :global_variables

  def configure_permitted_parameters
    # For additional fields in app/views/devise/registrations/new.html.erb
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :nickname,:phone_number, :role])

    # For additional in app/views/devise/registrations/edit.html.erb
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :nickname,:phone_number, :role])
  end

  def global_variables
    # players and referees belong to a club, the admin belongs to the sample club
    @sample_club = Club.find_by(name: "your tennis club")

    @club = current_user ? current_user.club : @sample_club
    @admin = User.find_by(role: "admin")
    @referee = User.find_by(role: "referee", club_id: @club.id)
  end

  def after_sign_in_path_for(resource)
    root_path
  end

  def set_club_and_round
    # instantiates variables @club and @round
    # for use in #index, #manage_my_box in Boxes and user_box_scores/index views forms
    clubs = Club.all.reject { |club| club == @sample_club }
    @club_names = clubs.map(&:name) # dropdown in the form

    if current_user != @admin || params[:club_name]
      # user belongs to a club (= is a player or a referee),
      # or has chosen a club in the clubs form (params[:club_name] is defined)
      @club = Club.find_by(name: params[:club_name]) if @club == @sample_club
      @start_dates = @club.rounds.map(&:start_date).sort.reverse # dropdown in the form
    end

    if params[:round_start]
      # user has answered the rounds form
      @round = Round.find_by(start_date: params[:round_start].to_time, club_id: @club.id)
      # @club = Club.find_by(name: params[:club_name])
      @boxes = @round.boxes.sort
    end
  end

  # -------------------------------------------------------------------------------------------------------------------
  # the 3 methods #current_round, #my_box and #match_score are called
  # - from #show (+ #show_list and #show_referee) in BoxesControllers
  # - and from #show in MatchesController

  def current_round(club_id)
    # given a club_id, returns its current round
    Round.current.find_by(club_id: club_id)
  end

  def my_box(round, player = current_user)
    # given a round, returns player's box for that round
    player.user_box_scores.map(&:box).select { |box| box.round == round }[0]
  end

  def match_score(match, player)
    match.user_match_scores.select { |user_match_score| user_match_score.user == player }[0]
  end

  # -------------------------------------------------------------------------------------------------------------------
  # the method #rank_players is called
  # - from #index in UserBoxScoresController
  # - and from #create in MatchesController

  def rank_players(scores)
    @tieds = [] # populated in #add_to_tieds
    scores = scores.sort { |a, b| compare(a, b) }
    # updates the rank field in the UserBoxScore database

    # previous ranking (flawed), based on points only :

    # points_array = scores.map(&:points)
    # sorted_points = points_array.sort.uniq.reverse
    # scores.each do |score|
    #   score.update(rank: sorted_points.index(score.points) + 1)
    # end

    # new ranking based on sorting criterias and ties :

    rank_tied = 1
    player = scores.first
    ranks = scores.map do |score|
      rank_tied = scores.index(score) + 1 unless @tieds.include?(score) && compare(player, score).zero?
      player = score
      rank_tied
    end

    # updates ranks in the database
    scores.each_with_index { |score, index| score.update(rank: ranks[index]) }
  end

  def compare(a, b)
    # the 4 compare methods use the spaceship operator
    # a <=> b returns -1 (if a<b), 0 (if a=b), 1 (if a>b) or nil (if a, b not comparable)
    comparison = compare_points(a, b)
    return comparison unless comparison.zero?

    comparison = compare_matches_played(a, b)
    return comparison unless comparison.zero?

    comparison = compare_set_ratio(a, b)
    return comparison unless comparison.zero?

    comparison = compare_game_ratio(a, b)
    return comparison unless comparison.zero?

    add_to_tieds(a, b)

    comparison
  end

  def compare_points(a, b)
    b.points <=> a.points
  end

  def compare_matches_played(a, b)
    b.games_played <=> a.games_played
  end

  def compare_set_ratio(a, b)
    (b.sets_played.zero? ? 0 : b.sets_won.to_f / b.sets_played) <=> (a.sets_played.zero? ? 0 : a.sets_won.to_f / a.sets_played)
  end

  def compare_game_ratio(a, b)
    (b.games_played.zero? ? 0 : b.games_won.to_f / b.games_played) <=> (a.games_played.zero? ? 0 : a.games_won.to_f / a.games_played)
  end

  def add_to_tieds(*players)
    players.each { |player| @tieds << player }
    @tieds.uniq!
  end

end

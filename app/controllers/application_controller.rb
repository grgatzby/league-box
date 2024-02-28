class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :global_variables
  helper_method :round_label  # allows the #round_label method to be called from views
  # before_action :set_locale

  # application schema in https://kitt.lewagon.com/db/95868
  # Existing features:
  # - players can: view a box (in list or table view), enter a new match score in their own box, view all boxes,
  #                view the league table, access their box chatroom.
  # - referees can: view a box (in list or table view), enter / edit / delete a match score, view all boxes,
  #                 view the league table, access the #general chatroom and all of their club's chatrooms,
  #                 request a new round creation.
  # - admin can: view a box (in list or table view), enter / edit / delete a match score, view all boxes,
  #              view the league table, access the #general chatroom and all other chatrooms,
  #              create a new club and its boxes (from a CSV file), create a new round, from an existing one.

  def default_url_options
    { locale: I18n.locale }
  end

  around_action :switch_locale

  def switch_locale(&action)
    locale = params[:locale] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

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
    @current_round = current_round(@club.id)
    @admin = User.find_by(role: "admin")
    # @referee = User.find_by(role: "referee", club_id: @club.id) #TO DO : role includes referee
    @referee = User.find_by("club_id = ? AND role like ?", @club.id, "%referee%")
    @general_chatroom = Chatroom.find_by(name: "general") || Chatroom.create(name: "general")
    # time_zone (dependency on gem tzinfo-data): used to convert UTC persisted times in local time
    @tz = TZInfo::Timezone.get("Europe/Paris")
    @is_mobile = mobile_device?
  end

  def after_sign_in_path_for(resource)
    user_box_scores_path
  end

  def set_club_round
    # instantiate variables @club from params[:club_id], and @round from params[:round_id]
    # if they have been selected from the _select_club_round forms
    # method called from #index, #my_scores in Boxes and user_box_scores/index views forms
    clubs = Club.all.reject { |club| club == @sample_club }
    @club_names = clubs.map(&:name) # dropdown list in the select_club form

    if current_user != @admin || params[:club_id]
      # user is a player or a referee (belongs to a club)),
      # or admin has selected a club from the form (club name is defined as params[:club_id])
      if @club == @sample_club
        @club = is_number?(params[:club_id]) ? Club.find(params[:club_id]) : Club.find_by(name: params[:club_id])
        # raise
      end
      @start_dates = @club.rounds.map(&:start_date).sort.reverse # dropdown in the select round form
      @start_dates = @start_dates.map { |round_start_date| round_start_date.strftime('%d/%m/%Y') }
      @league_starts = @club.rounds.map(&:league_start).sort
      @league_starts = @league_starts.map { |round_league_start| round_league_start.strftime('%d/%m/%Y') }.uniq
      if params[:round_id]
        @round = is_number?(params[:round_id]) ? Round.find(params[:round_id]) : Round.find_by(start_date: params[:round_id].to_time, club_id: @club.id)
        if @round
          @selected_date = @round.start_date.strftime('%d/%m/%Y')
        else
          flash[:notice] = t('.valid_round_flash')
          redirect_back(fallback_location: request.path)
          return
        end
      else
        @round = current_round(@club.id)
      end
      @round_nb = round_label(@round)
      @boxes = @round.boxes.sort
    end
  end

  def is_number?(string)
    # returns true if string contains only digits
    string.scan(/\D/).empty?
  end

  # -------------------------------------------------------------------------------------------------------------------
  # the #current_round, #my_scores and #match_score methods are invoked
  # - from #show and #show_list methods in BoxesControllers
  # - from #show method in MatchesController

  def current_round(club_id)
    # given a club_id, returns its current round or the last existing round
    Round.current.find_by(club_id: club_id) || Round.where(club_id: club_id).order(:start_date).last
  end

  def last_round(player = current_user)
    # given a player, returns its last played round
    player.user_box_scores.map(&:box).map(&:round).max { |a, b| a.start_date <=> b.start_date }
  end

  def my_own_box(round, player = current_user)
    # given a round, returns player's box for that round
    player.user_box_scores.map(&:box).select { |box| box.round == round }[0]
  end

  def match_score(match, player)
    # given a match (has two user_match_scores) and a player, returns the user_match_score for that player
    # match.user_match_scores.select { |user_match_score| user_match_score.user == player }[0]
    match.user_match_scores.where(user_id: player)[0]
  end

  # -------------------------------------------------------------------------------------------------------------------
  # the #rank_players method is invoked
  # - by #index in UserBoxScoresController
  # - and by #create in MatchesController

  def rank_players(user_box_scores, *from)
    # updates the rank field in the UserBoxScore database
    from = from[0] || "index" # "index_league" or "index"

    # old type ranking based on points only (not used, for initial tests only):
    # points_array = scores.map(&:points)
    # sorted_points = points_array.sort.uniq.reverse
    # scores.each do |score|
    #   score.update(rank: sorted_points.index(score.points) + 1)
    # end

    # current correct ranking based on 4 sorting criterias and ties :
    @tieds = [] # populated in #add_to_tieds called by #compare
    user_box_scores = user_box_scores.sort { |a, b| compare(a, b, from) }
    rank_tied = 1
    player = user_box_scores.first
    ranks = user_box_scores.map do |score|
      rank_tied = user_box_scores.index(score) + 1 unless @tieds.include?(score) && compare(player, score, from).zero?
      player = score
      rank_tied
    end

    # updates ranks in the database
    if from == "index_league"
      user_box_scores.each_with_index { |score, index| score[1][:rank] = ranks[index] }
    else # from == "index"
      user_box_scores.each_with_index { |score, index| score.update(rank: ranks[index]) }
    end
  end

  def compare(ubs_a, ubs_b, from)
    # ranking based on 4 sorting criterias (points, nb of matches played, highest set ratio, highest game ratio)
    # the 4 compare_ methods all use the spaceship operator:
    # a <=> b returns -1 (if a<b), 0 (if a=b), 1 (if a>b) or nil (if a, b are not comparable)

    # Ranking criterias:
    # 1 - most points won in the round
    comparison = compare_points(ubs_a, ubs_b, from)
    return comparison unless comparison.zero?

    # 2 - most matches played
    comparison = compare_matches_played(ubs_a, ubs_b, from)
    return comparison unless comparison.zero?

    # 3 - highest ratio of Sets Won to Sets Played %
    comparison = compare_set_ratio(ubs_a, ubs_b, from)
    return comparison unless comparison.zero?

    # 4 - highest ratio of Games Won to Games Played %
    comparison = compare_game_ratio(ubs_a, ubs_b, from)
    return comparison unless comparison.zero?

    add_to_tieds(ubs_a, ubs_b, from)

    comparison
  end

  def compare_points(a, b, from)
    if from == "index_league"
      b[1][:points] <=> a[1][:points]
    else # from == "index"
      b.points <=> a.points
    end
  end

  def compare_matches_played(a, b, from)
    if from == "index_league"
      b[1][:matches_played] <=> a[1][:matches_played]
    else
      b.matches_played <=> a.matches_played
    end
  end

  def compare_set_ratio(a, b, from)
    if from == "index_league"
      (b[1][:sets_played].zero? ? 0 : b[1][:sets_won].to_f / b[1][:sets_played]) <=> (a[1][:sets_played].zero? ? 0 : a[1][:sets_won].to_f / a[1][:sets_played])
    else # from == "index"
      (b.sets_played.zero? ? 0 : b.sets_won.to_f / b.sets_played) <=> (a.sets_played.zero? ? 0 : a.sets_won.to_f / a.sets_played)
    end
  end

  def compare_game_ratio(a, b, from)
    if from == "index_league"
      (b[1][:games_played].zero? ? 0 : b[1][:games_won].to_f / b[1][:games_played]) <=> (a[1][:games_played].zero? ? 0 : a[1][:games_won].to_f / a[1][:games_played])
    else # from == "index"
      (b.games_played.zero? ? 0 : b.games_won.to_f / b.games_played) <=> (a.games_played.zero? ? 0 : a.games_won.to_f / a.games_played)
    end
  end

  def add_to_tieds(*players)
    players.each { |player| @tieds << player }
    @tieds.uniq!
  end

  def mobile_device?
    # returns true if device is a mobile (used for mobile display)
    request.user_agent =~ /Mobile|webOS/
  end

  def local_path(path)
    # replaces stale locale with current locale in the path string
    # path.gsub(/en|fr|nl/, locale.to_s) if path
    path&.gsub(/en|fr|nl/, locale.to_s) # Ruby Safe Navigation
  end

  def round_label(round)
    # returns round label in format "yy/mm_Rnn" where
    # yy/mm is the tournament start date and nn is the rank of the round in the tournament
    league_start = round.league_start
    rounds_ordered = Round.where(league_start:, club_id: round.club)
                          .order('start_date ASC')
                          .map(&:id)
    "#{l(league_start, format: :yyymm_date)}_R#{format('%02d', rounds_ordered.index(round.id) + 1)}"
  end

  def redirect_to_back(options = {})
    # alternative to redirect_back method, adding more params, courtesy of https://www.filippoliverani.com/pass-params-rails-redirect-back
    uri = URI(request.referer)
    new_query = Rack::Utils.parse_nested_query(uri.query).merge(options.transform_keys! {|k| k.to_s })
    uri.query = options.delete(:params)&.to_query
    uri.fragment = options.delete(:anchor)
    redirect_to("#{uri}?#{new_query.to_query}")
  end

  def download_csv(file = "#{Rails.root}/public/data.csv", league_type, club_name)
    if File.exist?(file)
      send_file file, filename: "#{club_name}-#{league_type}[#{Date.today}].csv", disposition: 'attachment', type: 'text/csv'
    end
  end

  def my_box?(box, player = current_user)
    # return true if player belongs to box, false if not
    # player.role == "player" && box == player.user_box_scores.first.box
    box.user_box_scores.map(&:user).select { |user| user == player }.size.positive?
  end

  def init_stats
    # set the global statistic variables for the stats to be displayed in the view pages
    @nb_matches = @round.boxes.map { |box| box.user_box_scores.count * (box.user_box_scores.count - 1) / 2 }.sum
    @nb_matches_played = @round.boxes.map { |box| box.matches.count }.sum
    @days_left = @round.end_date - Date.today
    @round_days = @round.end_date - @round.start_date
    @nb_boxes = @round.boxes.count
    @nb_players = @round.boxes.map { |box| box.user_box_scores.count }.sum
    if @box
      @nb_box_matches = @box.user_box_scores.count * (@box.user_box_scores.count - 1) / 2
      @nb_box_matches_played = @box.matches.count
    end
    @my_current_box = my_own_box(@round)
    if @box == @my_current_box
      @my_nb_matches = @my_current_box.user_box_scores.count - 1
      @my_nb_matches_played = current_user.user_match_scores.select { |user_match_score| user_match_score.match.box == @my_current_box }.map(&:match).count
    end
  end

  def chatroom_name(box)
    # for a given box, return the chatroom name
    "#{box.round.club.name} - #{round_label(box.round)}:B#{format('%02d', box.box_number)}"
  end
end

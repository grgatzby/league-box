class ApplicationController < ActionController::Base
  require "securerandom"
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :global_variables
  helper_method :round_label  # allows the #round_label method to be called from views
  before_action :set_locale
  around_action :switch_locale

  # application schema in https://kitt.lewagon.com/db/95868
  # This app helps organise intra club tennis championship where players are divided into boxes of 4 to 6 players
  # Within a one month time frame (a round) players will compete against other players of their box; at the end of the round
  # the best players in each box are upgraded one or two boxes, the worst are downgraded one or two boxes.
  # Available features:
  # - players can: view a box in list view or table view, enter their new match score, view all other boxes,
  #              view the round rank list and overall league table (all rounds aggregate), access their box chatroom.
  # - referees can additionnaly: enter / edit / delete a match score, access the #general chatroom (to chat with other clubs
  #              referees) and all of the chatrooms of their club, request a new round creation from the admin.
  # - admin can additionnaly: access any chatroom, create a new club and its boxes (from a formatted CSV file including the
  #              players list), create the next round.

# Source - https://stackoverflow.com/a
# Posted by MrYoshiji, modified by community. See post 'Timeline' for change history
# Retrieved 2025-11-19, License - CC BY-SA 4.0

  ALLOWED_LOCALES = %w( fr en nl ).freeze
  DEFAULT_LOCALE = 'fr'.freeze

  def set_locale
#    I18n.locale = extract_locale_from_headers
    I18n.default_locale = extract_locale_from_headers
  end


  rescue_from ActionController::InvalidAuthenticityToken, with: :bad_token
  def bad_token
    flash[:notice] = t('.invalid_login_alert')
    redirect_to root_path
  end

  def default_url_options
    { locale: I18n.locale }
  end

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

  # Set global variables available to all controllers and views
  # Called as before_action in all controllers
  # Sets: @sample_club, @club, @current_round, @admin, @referee, @general_chatroom, @tz, @is_mobile
  def global_variables
    # Sample club used for non-authenticated users and as admin's club
    @sample_club = Club.find_by(name: "your tennis club")
    @club = current_user ? current_user.club : @sample_club
    @current_round = current_round(@club.id)
    @admin = User.find_by(role: "admin")
    @my_current_box = my_own_box(current_round(current_user.club_id)) if current_user
    # Find referee (role includes "referee" - can be "referee" or "player referee")
    @referee = User.find_by("club_id = ? AND role like ?", @club.id, "%referee%")
    @general_chatroom = Chatroom.find_by(name: "general") || Chatroom.create(name: "general")
    # Time zone (dependency on gem tzinfo-data): used to convert UTC persisted times to local time
    @tz = TZInfo::Timezone.get("Europe/Paris")
    @is_mobile = mobile_device?
  end

  def after_sign_in_path_for(resource)
    contexts = TournamentContextResolver.new(resource).contexts

    if contexts.size > 1
      return tournament_chooser_path
    end

    if contexts.size == 1
      context = contexts.first
      session[:selected_tournament_round_id] = context[:round_id]
      session[:selected_tournament_club_id] = context[:club_id]
      session[:selected_tournament_format] = context[:format]
    else
      session.delete(:selected_tournament_round_id)
      session.delete(:selected_tournament_club_id)
      session.delete(:selected_tournament_format)
    end

    preference = resource.preference || Preference.find_or_create_by(user_id: resource.id) do |pref|
      pref.clear_format = false
    end

    if preference.landing_to_user_box_scores && contexts.size == 1
      context = contexts.first
      user_box_scores_path(round_id: context[:round_id], club_id: context[:club_id], tournament_format: context[:format])
    else
      root_path
    end
  end

  # Set club and round instance variables from form parameters
  # Called from club/round selection forms in multiple views
  # Sets: @club, @round, @rounds_dropdown, @league_starts, @round_nb, @boxes
  # Handles both numeric IDs and string names/date labels
  def set_club_round
    clubs = Club.all.reject { |club| club == @sample_club }
    @club_names = clubs.map(&:name) # dropdown list in the select_club form
    if session[:selected_tournament_club_id].present? && params[:club_id].blank?
      selected_context_club = Club.find_by(id: session[:selected_tournament_club_id])
      @club = selected_context_club if selected_context_club
    end

    if current_user != @admin || params[:club_id].present? || session[:selected_tournament_club_id].present?
      # user is a player or a referee (belongs to a club)),
      # or admin has selected a club (params[:club_id]) or has a club in session from a prior pick
      if params[:club_id].present?
        selected_club_id = params[:club_id].to_s
        @club = if is_number?(selected_club_id)
                  Club.find_by(id: selected_club_id)
                else
                  Club.find_by(name: selected_club_id)
                end
      elsif @club == @sample_club
        @club = is_number?(params[:club_id]) ? Club.find(params[:club_id]) : Club.find_by(name: params[:club_id])
      end
      @club ||= current_user.club
      all_club_rounds = @club.rounds
      formats_for_club = all_club_rounds.distinct.pluck(:tournament_format).compact.uniq
      formats_for_club = formats_for_club.sort_by { |f| Round::TOURNAMENT_FORMATS.index(f) || 99 }
      @tournament_format_options_for_admin = formats_for_club
      @show_tournament_format_selector_for_admin = (current_user == @admin && formats_for_club.size > 1)

      tf_param = params[:tournament_format].presence
      tf_param = nil if tf_param.present? && formats_for_club.any? && !formats_for_club.include?(tf_param)

      # Prefer explicit round_id; otherwise session round when still the same club (GET forms often send
      # club_id but omit round_id — without this we fall back to current_round and may load the wrong format).
      # Session round is only reused if tournament_format matches when a format filter is present.
      selected_round_id = params[:round_id].presence
      if selected_round_id.blank?
        session_club_id = session[:selected_tournament_club_id].to_s
        params_club_id = @club&.id.to_s
        same_club_as_session = session_club_id.present? && session_club_id == params_club_id
        if params[:club_id].blank? || same_club_as_session
          sr_id = session[:selected_tournament_round_id]
          if sr_id.present?
            sr = Round.find_by(id: sr_id)
            if sr && sr.club_id == @club.id && (tf_param.blank? || sr.tournament_format == tf_param)
              selected_round_id = sr_id
            end
          end
        end
      end
      if selected_round_id
        selected_round_id = selected_round_id.to_s
        selected_round_from_params = params[:round_id].present?
        @round = if is_number?(selected_round_id)
                   Round.find_by(id: selected_round_id, club_id: @club.id)
                 else
                   Round.find_by(start_date: round_dropdown_to_start_date(selected_round_id), club_id: @club.id)
                 end
        if @round
          session[:selected_tournament_round_id] = @round.id
          session[:selected_tournament_club_id] = @round.club_id
          session[:selected_tournament_format] = @round.tournament_format
          @selected_label = rounds_dropdown(@round)
        else
          session.delete(:selected_tournament_round_id)
          session.delete(:selected_tournament_club_id)
          session.delete(:selected_tournament_format)
          if selected_round_from_params
            flash[:notice] = t('.valid_round_flash')
            redirect_back(fallback_location: request.path)
            return
          else
            @round = resolve_round_for_club_after_miss(formats_for_club, tf_param)
          end
        end
      else
        @round = resolve_round_for_club_after_miss(formats_for_club, tf_param)
      end
      # Prefer round's format, then explicit param, then session — session can be stale (e.g. after switching format).
      selected_format = @round&.tournament_format.presence || tf_param.presence || session[:selected_tournament_format].presence
      if selected_format.present? && formats_for_club.any? && !formats_for_club.include?(selected_format)
        selected_format = formats_for_club.first
      end
      selected_format ||= formats_for_club.first if formats_for_club.size == 1
      @tournament_format_for_links = selected_format
      session[:selected_tournament_format] = selected_format if selected_format.present?
      rounds_for_dropdown = selected_format.present? ? all_club_rounds.where(tournament_format: selected_format) : all_club_rounds
      @rounds_dropdown = rounds_for_dropdown.map { |round| rounds_dropdown(round) }.sort.reverse # dropdown in the select round form
      rounds_for_league_dates = selected_format.present? ? all_club_rounds.where(tournament_format: selected_format) : all_club_rounds
      @league_starts = rounds_for_league_dates.map(&:league_start).compact.sort.uniq
      @league_starts = @league_starts.map { |d| d.strftime('%d/%m/%Y') }.uniq
      @round_nb = @round ? round_label(@round) : nil
      @boxes = @round ? @round.boxes.includes([user_box_scores: :user]).sort : []
      # @boxes = @round.boxes.sort
    end
  end

  # Check if a string contains only digits
  # Used to determine if params[:club_id] or params[:round_id] is a numeric ID or a name/date string
  # Returns: true if string is numeric, false otherwise
  def is_number?(string)
    string.scan(/\D/).empty?
  end

  # -------------------------------------------------------------------------------------------------------------------
  # Round and Match Helper Methods
  # Used by: BoxesController#show, BoxesController#show_list, MatchesController#show

  # Get current round for a club (round where current date is between start_date and end_date)
  # Falls back to last existing round if no current round
  # Parameters: club_id
  # Returns: Round object
  def current_round(club_id)
    Round.current.find_by(club_id: club_id) || Round.where(club_id: club_id).order(:start_date).last
  end

  # Current or latest round for a club restricted to one tournament format (singles / doubles / padel).
  def current_round_for_club_format(club_id, tournament_format)
    return nil unless tournament_format.present?

    Round.current.find_by(club_id: club_id, tournament_format: tournament_format) ||
      Round.where(club_id: club_id, tournament_format: tournament_format).order(:start_date).last
  end

  # Pick a round when none matched by id (invalid session or first load), using tournament_format param when present.
  def resolve_round_for_club_after_miss(formats_for_club, tf_param)
    selected_format = tf_param
    if selected_format.blank?
      s = session[:selected_tournament_format].presence
      selected_format = s if s && formats_for_club.include?(s)
    end
    if selected_format.blank?
      selected_format = formats_for_club.first if formats_for_club.size == 1
    end
    if selected_format.blank? && formats_for_club.size > 1
      selected_format = formats_for_club.first
    end

    r = current_round_for_club_format(@club.id, selected_format) if selected_format.present?
    r ||= current_round(@club.id)
    if r
      session[:selected_tournament_round_id] = r.id
      session[:selected_tournament_club_id] = r.club_id
      session[:selected_tournament_format] = r.tournament_format
    end
    r
  end

  # Get last round played by a player
  # Parameters: player (User object, defaults to current_user)
  # Returns: Round object (most recent by start_date)
  def last_round(player = current_user)
    player.user_box_scores.map(&:box).map(&:round).max { |a, b| a.start_date <=> b.start_date }
  end

  # Get user_match_score for a specific player in a match
  # Parameters: match (Match object), player (User object or ID)
  # Returns: UserMatchScore object for that player
  def match_score(match, player)
    match.user_match_scores.where(user_id: player)[0]
  end

  # -------------------------------------------------------------------------------------------------------------------
  # Ranking System Methods
  # Used by: UserBoxScoresController#index, MatchesController#create

  # Rank players based on 4 criteria with tie handling
  # Ranking criteria (in order):
  #   1. Most points won
  #   2. Most matches played
  #   3. Highest set win ratio (sets_won / sets_played)
  #   4. Highest game win ratio (games_won / games_played)
  # Parameters:
  #   user_box_scores: Array of UserBoxScore objects or [player, {stats_hash}] tuples
  #   from: "index" (single round) or "index_league" (tournament aggregate)
  # Updates rank field in database for each player
  def rank_players(user_box_scores, *from)
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

  # Rank doubles teams by same criteria as players
  def rank_teams(team_box_scores)
    tieds = []
    sorted = team_box_scores.sort do |a, b|
      cmp = b.points <=> a.points
      cmp = (b.matches_played <=> a.matches_played) if cmp.zero?
      cmp = ((b.sets_played.zero? ? 0 : b.sets_won.to_f / b.sets_played) <=> (a.sets_played.zero? ? 0 : a.sets_won.to_f / a.sets_played)) if cmp.zero?
      cmp = ((b.games_played.zero? ? 0 : b.games_won.to_f / b.games_played) <=> (a.games_played.zero? ? 0 : a.games_won.to_f / a.games_played)) if cmp.zero?
      cmp = a.id <=> b.id if cmp.zero?
      tieds << [a, b] if cmp.zero?
      cmp
    end

    rank_tied = 1
    previous = sorted.first
    ranks = sorted.map do |score|
      same_as_previous = previous &&
                         previous.points == score.points &&
                         previous.matches_played == score.matches_played &&
                         (previous.sets_played.zero? ? 0 : previous.sets_won.to_f / previous.sets_played) == (score.sets_played.zero? ? 0 : score.sets_won.to_f / score.sets_played) &&
                         (previous.games_played.zero? ? 0 : previous.games_won.to_f / previous.games_played) == (score.games_played.zero? ? 0 : score.games_won.to_f / score.games_played)
      rank_tied = sorted.index(score) + 1 unless same_as_previous
      previous = score
      rank_tied
    end

    sorted.each_with_index { |score, index| score.update(rank: ranks[index]) }
    sorted
  end

  # Compare two UserBoxScore records for ranking
  # Uses spaceship operator (<=>) which returns -1 (a<b), 0 (a=b), 1 (a>b), or nil
  # Compares using 4 criteria in order (stops at first non-zero comparison):
  #   1. Points (descending)
  #   2. Matches played (descending)
  #   3. Set win ratio (descending)
  #   4. Game win ratio (descending)
  # If all criteria equal, players are marked as tied
  # Parameters: ubs_a, ubs_b (UserBoxScore objects or tuples), from ("index" or "index_league")
  # Returns: -1, 0, or 1
  def compare(ubs_a, ubs_b, from)
    # Ranking criterion 1: Most points won in the round
    comparison = compare_points(ubs_a, ubs_b, from)
    return comparison unless comparison.zero?

    # Ranking criterion 2: Most matches played
    comparison = compare_matches_played(ubs_a, ubs_b, from)
    return comparison unless comparison.zero?

    # Ranking criterion 3: Highest ratio of Sets Won to Sets Played (%)
    comparison = compare_set_ratio(ubs_a, ubs_b, from)
    return comparison unless comparison.zero?

    # Ranking criterion 4: Highest ratio of Games Won to Games Played (%)
    comparison = compare_game_ratio(ubs_a, ubs_b, from)
    return comparison unless comparison.zero?

    # All criteria equal: mark players as tied
    add_to_tieds(ubs_a, ubs_b, from)

    comparison
  end

  # Compare points between two players (used in ranking)
  # Returns: -1 if a < b, 0 if equal, 1 if a > b (sorted descending by points)
  def compare_points(a, b, from)
    if from == "index_league"
      b[1][:points].to_i <=> a[1][:points].to_i
    else # from == "index"
      b.points.to_i <=> a.points.to_i
    end
  end

  # Compare matches played between two players (used in ranking)
  # Returns: -1 if a < b, 0 if equal, 1 if a > b (sorted descending by matches_played)
  def compare_matches_played(a, b, from)
    if from == "index_league"
      b[1][:matches_played].to_i <=> a[1][:matches_played].to_i
    else
      b.matches_played.to_i <=> a.matches_played.to_i
    end
  end

  # Compare set win ratio between two players (used in ranking)
  # Calculates sets_won / sets_played ratio (handles division by zero)
  # Returns: -1 if a < b, 0 if equal, 1 if a > b (sorted descending by ratio)
  def compare_set_ratio(a, b, from)
    if from == "index_league"
      b_sets_played = b[1][:sets_played].to_i
      b_sets_won = b[1][:sets_won].to_i
      a_sets_played = a[1][:sets_played].to_i
      a_sets_won = a[1][:sets_won].to_i
      (b_sets_played.zero? ? 0 : b_sets_won.to_f / b_sets_played) <=> (a_sets_played.zero? ? 0 : a_sets_won.to_f / a_sets_played)
    else # from == "index"
      b_sets_played = b.sets_played.to_i
      b_sets_won = b.sets_won.to_i
      a_sets_played = a.sets_played.to_i
      a_sets_won = a.sets_won.to_i
      (b_sets_played.zero? ? 0 : b_sets_won.to_f / b_sets_played) <=> (a_sets_played.zero? ? 0 : a_sets_won.to_f / a_sets_played)
    end
  end

  # Compare game win ratio between two players (used in ranking)
  # Calculates games_won / games_played ratio (handles division by zero)
  # Returns: -1 if a < b, 0 if equal, 1 if a > b (sorted descending by ratio)
  def compare_game_ratio(a, b, from)
    if from == "index_league"
      b_games_played = b[1][:games_played].to_i
      b_games_won = b[1][:games_won].to_i
      a_games_played = a[1][:games_played].to_i
      a_games_won = a[1][:games_won].to_i
      (b_games_played.zero? ? 0 : b_games_won.to_f / b_games_played) <=> (a_games_played.zero? ? 0 : a_games_won.to_f / a_games_played)
    else # from == "index"
      b_games_played = b.games_played.to_i
      b_games_won = b.games_won.to_i
      a_games_played = a.games_played.to_i
      a_games_won = a.games_won.to_i
      (b_games_played.zero? ? 0 : b_games_won.to_f / b_games_played) <=> (a_games_played.zero? ? 0 : a_games_won.to_f / a_games_played)
    end
  end

  # Add players to tied players array (for display purposes)
  # Players with identical stats across all 4 criteria are considered tied
  def add_to_tieds(*players)
    players.each { |player| @tieds << player }
    @tieds.uniq!
  end

  # Detect if the current request is from a mobile device
  # Used to adjust display and styling for mobile views
  # Returns: true if mobile device detected, false otherwise
  def mobile_device?
    request.user_agent =~ /Mobile|webOS/
  end

  # Replace stale locale in path string with current locale
  # Used to update URLs with correct locale parameter
  # Example: "/en/boxes" => "/fr/boxes" (if current locale is fr)
  def local_path(path)
    path&.gsub(/en|fr|nl/, I18n.locale.to_s) # Ruby Safe Navigation
  end

  # Delegates to Round#round_label (yyyy/mm_RnnS — S/D/P by format); see Round model.
  def round_label(round)
    round.round_label
  end

  # Generate dropdown label for round selection
  # Format: "yy/mm_RnnS (dd/mm/yyyy)" - includes round label and start date
  def rounds_dropdown(round)
    "#{round_label(round)} (#{round.start_date.strftime('%d/%m/%Y')})"
  end

  # Extract round start_date from dropdown label (robust to label length / S-D-P suffix)
  def round_dropdown_to_start_date(label)
    m = label.to_s.match(/\((\d{2}\/\d{2}\/\d{4})\)/)
    raise ArgumentError, "invalid round dropdown label: #{label.inspect}" unless m

    Date.strptime(m[1], "%d/%m/%Y")
  end

  # Redirect back to referer with additional parameters
  # Alternative to redirect_back method, allows adding extra params
  # Credits: https://www.filippoliverani.com/pass-params-rails-redirect-back
  def redirect_to_back(options = {})
    uri = URI(request.referer)
    new_query = Rack::Utils.parse_nested_query(uri.query).merge(options.transform_keys! {|k| k.to_s })
    uri.query = options.delete(:params)&.to_query
    uri.fragment = options.delete(:anchor)
    redirect_to("#{uri}?#{new_query.to_query}")
  end

  # Download CSV file with league table data
  # Parameters:
  #   file: File path (e.g., "#{Rails.root}/public/data.csv")
  #   league_type: Type identifier (e.g., "League Table-R01" or "League Table-T2024-10-01")
  #   club_name: Club name for filename
  #   source_method: Optional trace tag (e.g., "boxes#round_scores_to_csv")
  def download_csv(file, league_type, club_name, source_method = nil)
    if File.exist?(file)
      send_file file,
                filename: csv_download_filename(club_name, league_type, source_method),
                disposition: "attachment",
                type: "text/csv"
    end
  end

  def csv_download_filename(club_name, league_type, source_method = nil)
    trace = source_method.presence || "#{controller_name}##{action_name}"
    "#{club_name}-#{league_type}[#{Date.today}]-#{trace}-#{SecureRandom.hex(4)}.csv"
  end

  # Check if a player belongs to a specific box
  # Parameters: box (Box object), player (User object, defaults to current_user)
  # Returns: true if player is in the box, false otherwise
  def my_box?(box, player = current_user)
    box.user_box_scores.map(&:user).select { |user| user == player }.size.positive?
  end

  # Get a player's box for a specific round
  # Parameters: round (Round object), player (User object, defaults to current_user)
  # Returns: Box object for that player in that round, or nil if not found
  def my_own_box(round, player = current_user)
    player.user_box_scores.includes([box: :round]).map(&:box).select { |box| box.round == round }[0]
  end

  # Initialize statistics variables for display in views
  # Sets: @nb_matches, @nb_matches_played, @days_left, @round_days, @last_round_match_date, @nb_boxes, @nb_players
  # Also sets box-specific stats if @box is present
  #
  # Round-robin capacity uses one "entity" per competitor: singles = players (user_box_scores), doubles/padel = teams
  # (team_box_scores). Using user_box_scores for doubles would count both members of each team and inflate slots (e.g. 28 vs 6).
  def init_stats
    doubles = @round.doubles_format?
    includes = doubles ? [:user_box_scores, :team_box_scores, :matches] : [:user_box_scores, :matches]
    @nb_matches = @round.boxes.includes(includes).map { |box| round_robin_match_count(box_competitors_count(box, doubles)) }.sum
    @nb_matches_played = @round.boxes.map { |box| box.matches.size }.sum
    @days_left = @round.end_date - Date.today
    @round_days = @round.end_date - @round.start_date
    @last_round_match_date = last_round_match_date(@round)
    @nb_boxes = @round.boxes.size
    @nb_players = @round.boxes.map { |box| box.user_box_scores.size }.sum
    if @box
      @nb_box_matches = round_robin_match_count(box_competitors_count(@box, doubles))
      @nb_box_matches_played = @box.matches.size
      @last_box_match_date = last_box_match_date(@box)
      if @box == @my_box
        my_n = box_competitors_count(@my_box, doubles)
        @my_nb_matches = my_n.positive? ? my_n - 1 : 0
        @my_nb_matches_played = current_user.user_match_scores.select { |user_match_score| user_match_score.match.box == @my_box }.map(&:match).size
      end
    end
  end

  # Delegates to Box#chatroom_label (round segment = Round#round_label, includes S/D/P before ":Bnn").
  def chatroom_name(box)
    box.chatroom_label
  end

  # Get the most recent match date in a round (across all boxes)
  # Returns: Time object or nil if no matches
  def last_round_match_date(round)
    round.boxes.map { |box| box.matches if box.matches.size.positive? }.flatten.compact.map(&:time).max
  end

  # Get the most recent match date in a box
  # Returns: Time object or nil if no matches
  def last_box_match_date(box)
    box.matches.map(&:time).max if box.matches.size.positive?
  end

  private

  # Number of round-robin pairings for n competitors (each pair plays once).
  def round_robin_match_count(n)
    n = n.to_i
    return 0 if n < 2

    n * (n - 1) / 2
  end

  # Singles: players per box; doubles/padel: teams per box (not 2× players).
  def box_competitors_count(box, doubles_round)
    doubles_round ? box.team_box_scores.size : box.user_box_scores.size
  end

  # Extract locale from browser Accept-Language header
  # Returns: one of ALLOWED_LOCALES or DEFAULT_LOCALE
  def extract_locale_from_headers
    browser_locale = request.env['HTTP_ACCEPT_LANGUAGE'].scan(/^[a-z]{2}/).first
    if ALLOWED_LOCALES.include?(browser_locale)
      browser_locale
    else
      DEFAULT_LOCALE
    end
  end

end

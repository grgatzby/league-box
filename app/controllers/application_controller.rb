class ApplicationController < ActionController::Base
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
    # user_box_scores_path
    boxes_path
  end

  # Set club and round instance variables from form parameters
  # Called from club/round selection forms in multiple views
  # Sets: @club, @round, @rounds_dropdown, @league_starts, @round_nb, @boxes
  # Handles both numeric IDs and string names/date labels
  def set_club_round
    clubs = Club.all.reject { |club| club == @sample_club }
    @club_names = clubs.map(&:name) # dropdown list in the select_club form

    if current_user != @admin || params[:club_id]
      # user is a player or a referee (belongs to a club)),
      # or admin has selected a club from the form (club name is defined as params[:club_id])
      if @club == @sample_club
        @club = is_number?(params[:club_id]) ? Club.find(params[:club_id]) : Club.find_by(name: params[:club_id])
      end
      @rounds_dropdown = @club.rounds.map { |round| rounds_dropdown(round) }.sort.reverse # dropdown in the select round form
      @league_starts = @club.rounds.map(&:league_start).sort
      @league_starts = @league_starts.map { |round_league_start| round_league_start.strftime('%d/%m/%Y') }.uniq
      if params[:round_id]
        @round = is_number?(params[:round_id]) ? Round.find(params[:round_id]) : Round.find_by(start_date: round_dropdown_to_start_date(params[:round_id]), club_id: @club.id)
        if @round
          @selected_label = rounds_dropdown(@round)
        else
          flash[:notice] = t('.valid_round_flash')
          redirect_back(fallback_location: request.path)
          return
        end
      else
        @round = current_round(@club.id)
      end
      @round_nb = round_label(@round)
      @boxes = @round.boxes.includes([user_box_scores: :user]).sort
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
      b[1][:points] <=> a[1][:points]
    else # from == "index"
      b.points <=> a.points
    end
  end

  # Compare matches played between two players (used in ranking)
  # Returns: -1 if a < b, 0 if equal, 1 if a > b (sorted descending by matches_played)
  def compare_matches_played(a, b, from)
    if from == "index_league"
      b[1][:matches_played] <=> a[1][:matches_played]
    else
      b.matches_played <=> a.matches_played
    end
  end

  # Compare set win ratio between two players (used in ranking)
  # Calculates sets_won / sets_played ratio (handles division by zero)
  # Returns: -1 if a < b, 0 if equal, 1 if a > b (sorted descending by ratio)
  def compare_set_ratio(a, b, from)
    if from == "index_league"
      (b[1][:sets_played].zero? ? 0 : b[1][:sets_won].to_f / b[1][:sets_played]) <=> (a[1][:sets_played].zero? ? 0 : a[1][:sets_won].to_f / a[1][:sets_played])
    else # from == "index"
      (b.sets_played.zero? ? 0 : b.sets_won.to_f / b.sets_played) <=> (a.sets_played.zero? ? 0 : a.sets_won.to_f / a.sets_played)
    end
  end

  # Compare game win ratio between two players (used in ranking)
  # Calculates games_won / games_played ratio (handles division by zero)
  # Returns: -1 if a < b, 0 if equal, 1 if a > b (sorted descending by ratio)
  def compare_game_ratio(a, b, from)
    if from == "index_league"
      (b[1][:games_played].zero? ? 0 : b[1][:games_won].to_f / b[1][:games_played]) <=> (a[1][:games_played].zero? ? 0 : a[1][:games_won].to_f / a[1][:games_played])
    else # from == "index"
      (b.games_played.zero? ? 0 : b.games_won.to_f / b.games_played) <=> (a.games_played.zero? ? 0 : a.games_won.to_f / a.games_played)
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
    path&.gsub(/en|fr|nl/, locale.to_s) # Ruby Safe Navigation
  end

  # Generate round label in format "yy/mm_Rnn"
  # Format: yy/mm is tournament start date (league_start), nn is round number in tournament
  # Example: "24/10_R01" (October 2024, Round 1)
  def round_label(round)
    league_start = round.league_start
    rounds_ordered = Round.where(league_start:, club_id: round.club)
                          .order('start_date ASC')
                          .map(&:id)
    "#{l(league_start, format: :yyymm_date)}_R#{format('%02d', rounds_ordered.index(round.id) + 1)}"
  end

  # Generate dropdown label for round selection
  # Format: "yy/mm_Rnn (dd/mm/yyyy)" - includes round label and start date
  def rounds_dropdown(round)
    "#{round_label(round)} (#{round.start_date.strftime('%d/%m/%Y')})"
  end

  # Extract round start_date from dropdown label
  # Label format: "yy/mm_Rnn (dd/mm/yyyy)" - extracts date portion at position [13, 10]
  def round_dropdown_to_start_date(label)
    label[13, 10].to_date
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
  #   file: File path (default: "#{Rails.root}/public/data.csv")
  #   league_type: Type identifier (e.g., "League Table-R01" or "League Table-T2024-10-01")
  #   club_name: Club name for filename
  def download_csv(file = "#{Rails.root}/public/data.csv", league_type, club_name)
    if File.exist?(file)
      send_file file, filename: "#{club_name}-#{league_type}[#{Date.today}].csv", disposition: 'attachment', type: 'text/csv'
    end
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
  def init_stats
    # @nb_matches = @round.boxes.map { |box| box.user_box_scores.size * (box.user_box_scores.size - 1) / 2 }.sum
    @nb_matches = @round.boxes.includes([:user_box_scores, :matches]).map { |box| box.user_box_scores.size * (box.user_box_scores.size - 1) / 2 }.sum
    @nb_matches_played = @round.boxes.map { |box| box.matches.size }.sum
    @days_left = @round.end_date - Date.today
    @round_days = @round.end_date - @round.start_date
    @last_round_match_date = last_round_match_date(@round)
    @nb_boxes = @round.boxes.size
    @nb_players = @round.boxes.map { |box| box.user_box_scores.size }.sum
    if @box
      @nb_box_matches = @box.user_box_scores.size * (@box.user_box_scores.size - 1) / 2
      @nb_box_matches_played = @box.matches.size
      @last_box_match_date = last_box_match_date(@box)
      if @box == @my_box
        @my_nb_matches = @my_box.user_box_scores.size - 1
        @my_nb_matches_played = current_user.user_match_scores.select { |user_match_score| user_match_score.match.box == @my_box }.map(&:match).size
      end
    end
  end

  # Generate chatroom name for a box
  # Format: "Club Name - yy/mm_Rnn:Bnn" (Club - Round:Box number)
  # Example: "My Club - 24/10_R01:B03"
  def chatroom_name(box)
    "#{box.round.club.name} - #{round_label(box.round)}:B#{format('%02d', box.box_number)}"
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

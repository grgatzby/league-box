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
    @sample_club = Club.find_by(name: "My tennis club")
    # players and referees belong to a club, the admin belongs to the sample club

    @club = current_user ? current_user.club : @sample_club
    @admin = User.find_by(role: "admin")
    @referee = User.find_by(role: "referee", club_id: @club.id)
  end

  def after_sign_in_path_for(resource)
    boxes_path
  end

  def set_club_and_round
    # defines variables @club and @round for use in #index, #manage_my_box in Boxes and user_box_scores/index views forms
    clubs = Club.all.reject { |club| club == @sample_club }
    @club_names = clubs.map(&:name) # dropdown in the form

    if current_user != @admin || params[:club_name]
      # user belongs to a club (player or referee), or has answered the clubs form
      @club = Club.find_by(name: params[:club_name]) if @club == @sample_club
      @start_dates = @club.rounds.map(&:start_date) # dropdown in the form
    end

    if params[:round_start]
      # user has answered the rounds form
      @round = Round.find_by(start_date: params[:round_start].to_time, club_id: @club.id)
      # @club = Club.find_by(name: params[:club_name])
      @boxes = @round.boxes.sort
    end
  end

  # #current_round, and #my_box are called from #show, #show_list, and #show_referee in BoxesControllers
  # and from #show in MatchesController
  def current_round(user)
    # given a user, returns its current round
    Round.current.find_by(club_id: user.club_id)
  end

  def my_box(round, player = current_user)
    # given a round, returns player's box for that round
    player.user_box_scores.map(&:box).select { |box| box.round == round }[0]
  end

  def compute_points(match_scores)
    # called from #update in UserMatchScoresController and #create in MatchesController
    # and previously from #scores_NO_LONGER_USED in UserMatchScoresController
    # computes scores in match_scores (an array of 2 hashes)

    # Points rules:
    #   - Winner 20 points
    #   - Looser 10 points per set won + number of games per lost set
    #   - The championship tie-break counts as one set (no points awarded for the looser)

    results = compute_results(match_scores)
    # first set
    if match_scores[0][:score_set1] > match_scores[1][:score_set1]
      match_scores[0][:points] = 10
      match_scores[1][:points] = match_scores[1][:score_set1]
    else
      match_scores[0][:points] = match_scores[0][:score_set1]
      match_scores[1][:points] = 10
    end

    # second set
    if match_scores[0][:score_set2] > match_scores[1][:score_set2]
      match_scores[0][:points] += 10
      match_scores[1][:points] += match_scores[1][:score_set2]
    else
      match_scores[0][:points] += match_scores[0][:score_set2]
      match_scores[1][:points] += 10
    end

    # championship tie break
    if results[0] == 1 || results[1] == 1
      if match_scores[0][:score_tiebreak] > match_scores[1][:score_tiebreak]
        match_scores[0][:points] = 20
      else
        match_scores[1][:points] = 20
      end
    else
      match_scores[0][:score_tiebreak] = 0
      match_scores[1][:score_tiebreak] = 0
    end
    # returns results (ARRAY of won sets count for each player)
    results
  end

  def compute_results(match_scores)
    # called from UserMatchScoresController and MatchesController
    # computes and returns results (hash of won sets count for each player)

    results = { sets_won1: 0,
                sets_won2: 0 }

    # first set
    if match_scores[0][:score_set1] > match_scores[1][:score_set1]
      results[:sets_won1] += 1
    else
      results[:sets_won2] += 1
    end

    # second set
    if match_scores[0][:score_set2] > match_scores[1][:score_set2]
      results[:sets_won1] += 1
    else
      results[:sets_won2] += 1
    end

    # championship tie break
    if results[:sets_won1] == 1 || results[:sets_won2] == 1
      if match_scores[0][:score_tiebreak] > match_scores[1][:score_tiebreak]
        results[:sets_won1] += 1
      else
        results[:sets_won2] += 1
      end
    end
    # returns results (ARRAY of won sets count for each player)
    [results[:sets_won1], results[:sets_won2]]
  end

  def test_scores(match_scores, results)
    # called from UserMatchScoresController and MatchesController
    # returns true if scores entered in matches/new or user_match_scores/edit_both are valid,
    # returns false otherwise
    if (match_scores[0][:score_set1] < 4 && match_scores[1][:score_set1] < 4) ||
       (match_scores[0][:score_set2] < 4 && match_scores[1][:score_set2] < 4)
      flash[:alert] = "One score must be 4 for set 1 and set 2."
      false
    elsif (match_scores[0][:score_set1] == 4 && match_scores[1][:score_set1] == 4) ||
          (match_scores[0][:score_set2] == 4 && match_scores[1][:score_set2] == 4)
      flash[:alert] = "4-4 is not a valid score."
      false
    elsif (match_scores[0][:score_tiebreak] < 10 && match_scores[1][:score_tiebreak] < 10) &&
          (results[0] == 1 || results[1] == 1)
      flash[:alert] = "One tiebreak score must be at least 10."
      false
    elsif ((match_scores[0][:score_tiebreak] > 10 && match_scores[1][:score_tiebreak] < 9) ||
          (match_scores[0][:score_tiebreak] < 9 && match_scores[1][:score_tiebreak] > 10)) &&
          (results[0] == 1 || results[1] == 1)
      flash[:alert] = "One tiebreak score must be 10."
      false
    elsif (match_scores[0][:score_tiebreak] - match_scores[1][:score_tiebreak]).abs < 2 &&
          (results[0] == 1 || results[1] == 1)
      flash[:alert] = "Tiebreak score must be 2 clear."
      false
    else
      true
    end
  end
end

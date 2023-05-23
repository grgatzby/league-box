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
    root_path
  end

  def set_club_and_round
    # defines variables @club and @round for use in #index, #manage_my_box in Boxes and user_box_scores/index views forms
    clubs = Club.all.reject { |club| club == @sample_club }
    @club_names = clubs.map(&:name) # dropdown in the form

    if current_user != @admin || params[:club_name]
      # user belongs to a club (= is a player or a referee), or has answered the clubs form
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

  # #current_round, #my_box and #match_score are called from #show (+ #show_list and #show_referee) in BoxesControllers
  # and from #show in MatchesController
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
end

class UserBoxScoresController < ApplicationController
  require "csv"

  def index
    # displays the league table, allows user to sort the table by headers clicks

    set_club_round

    # @order dictates the sorting order of the selected header
    # it is passed from the partial _header_link.html.erb when a header is clicked
    if params[:order] && (params[:exsort] == params[:sort])
      @order = params[:order].to_i
    else
      @order = -1
    end
    if @round
      @user_box_scores = rank_players(@round.user_box_scores)
      @user_box_scores.reverse! if @order == 1
    end
    @sort = params[:sort]

    case params[:sort]
    when "Player"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| user_box_scores.user.last_name }
      @user_box_scores.reverse! if @order == 1
    when "Points"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| @order * user_box_scores.points }
    when "Box"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| -@order * user_box_scores.box.box_number }
    when "Matches"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| @order * user_box_scores.games_played }
    when "Matches Won"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| @order * user_box_scores.games_won }
    when "Sets"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| @order * user_box_scores.sets_played }
    when "Sets Won"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| @order * user_box_scores.sets_won }
    end
    @rules = "A player's league position is determined by the total number of points won in a round.<br />
            In the event that two or more players have the same number of points the league position will be
            determined by:
            <ol>
              <li>Head to Head result (if only 2 players on the same score)</li>
              <li>Most matches played</li>
              <li>Ratio of sets won to sets played</li>
              <li>Ratio of games won to games played</li>
            </ol>"
  end

  def new
  end

  def create
    # (admin only) create a club, its courts, players (from csv file), a round, its boxes and user_box_scores
    # the csv file must contain fields id, email, first_name, last_name, nickname, phone_number, role (players, referee)
    # players are allocated in boxes by id in descending order.

    csv_file = params[:csv_file]
    if csv_file.content_type == "text/csv"
      headers = CSV.foreach(csv_file).first
      if headers.sort - ["nickname"] == ["id", "email", "first_name", "last_name", "phone_number", "role"].sort
        # create club
        club = Club.create(name: params[:new_club_name])

        # create courts
        params[:nb_of_courts].to_i.times do |court_number|
          Court.create(
            name: court_number + 1,
            club_id: club.id
          )
        end
        # create round
        round = Round.create(start_date: params[:start_date].to_date, end_date: params[:end_date].to_date, club_id: club.id)

        # create array of users (players and club referees)
        users = []
        CSV.foreach(csv_file, headers: :first_row, header_converters: :symbol) do |row|
          user = User.create(row)
          user.update(club_id: club.id, password: "123456", nickname: user.nickname || (user.first_name + user.last_name[0]))
          users << user
        end
        referees = users.select { |user| user.role == "referee" }
        referees.each { |referee| referee.update(password: "654321") }
        players = users.select { |user| user.role == "player" }

        # create boxes and user_box_scores
        players_per_box = params[:players_per_box].to_i
        players_per_box = 6
        players_per_box -= 1 while players.count % players_per_box in 1..3
        nb_boxes = players.count / players_per_box
        box_players = []
        boxes = []
        nb_boxes.times do |box_index|
          boxes << Box.create(round_id: round.id, box_number: box_index + 1)
          box_players << players.shift(players_per_box)
          box_players[box_index].each do |player|
            UserBoxScore.create(user_id: player.id, box_id: boxes[box_index].id, points: 0, rank: 1,
                                sets_won: 0, sets_played: 0, games_won: 0, games_played: 0)
          end
        end
        redirect_to boxes_path(round_start: round.start_date, club_name: club.name)
      else
        flash[:notice] = 'Your headers must be "id", "email", "first_name", "last_name", ["nickname"], "phone_number", and "role".'
        redirect_back(fallback_location: new_user_box_score_path)
      end
    else
      flash[:notice] = "Please chose a csv file type."
      redirect_back(fallback_location: new_user_box_score_path)
    end
  end
end

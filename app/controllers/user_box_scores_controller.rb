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
    when t('.headers_line.player_header') # "Player"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| [user_box_scores.user.last_name, -@order * user_box_scores.rank] }
      @user_box_scores.reverse! if @order == 1
    when t('.headers_line.points_header') # "Points"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| [@order * user_box_scores.points, -@order * user_box_scores.rank] }
    when t('.headers_line.box_header') # "Box"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| [-@order * user_box_scores.box.box_number, -@order * user_box_scores.rank] }
    when t('.headers_line.matches_played_header') # "Matches Played"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| [@order * user_box_scores.games_played, -@order * user_box_scores.rank] }
    when t('.headers_line.matches_won_header') # "Matches Won"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| [@order * user_box_scores.games_won, -@order * user_box_scores.rank] }
    when t('.headers_line.sets_played_header') # "Sets Played"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| [@order * user_box_scores.sets_played, -@order * user_box_scores.rank] }
    when t('.headers_line.sets_won_header') # "Sets Won"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| [@order * user_box_scores.sets_won, -@order * user_box_scores.rank] }
    end
    @render_to_text = false
    if params[:to_text] == "true"
      @render_to_text = true
      # from https://stackoverflow.com/questions/7414267/strip-html-from-string-ruby-on-rails
      # to strip all html
      no_html_string = ActionView::Base.full_sanitizer.sanitize(render_to_string.encode("UTF-8"))
      send_data(no_html_string, template: :raw, filename: "/object.txt", type: "text/txt")
    elsif params[:to_csv] == "true"
      @file = league_table_to_csv(@round)
      # flash[:notice] = t('.file_csv_flash')
      flash[:notice] = @file
      assign_params = params.dup
      assign_params.delete(:to_csv)
      redirect_back(fallback_location: user_box_scores_path)
    end
  end

  def new
  end

  def create
    # (admin only) create a club, its courts, players (from csv file), a round, its boxes and user_box_scores
    # the csv file must contain fields id, email, first_name, last_name, nickname, phone_number, role (players, referee)
    # players are allocated in boxes by id in descending order.
    # TO DO: create a chatroom for each new box
    # maybe dealt with in the 20231018223106_add_reference_to_boxes migration file with the default value

    csv_file = params[:csv_file]
    if csv_file.content_type == "text/csv"
      headers = CSV.foreach(csv_file).first
      if headers.sort - ["nickname"] == ["id", "email", "first_name", "last_name", "phone_number", "role"].sort
        # create club
        club = Club.create(name: params[:new_club_name])

        # create courts
        params[:nb_of_courts].to_i.times { |court_number| Court.create(name: court_number + 1, club_id: club.id) }

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
        flash[:notice] = t('.header_flash')
        redirect_back(fallback_location: new_user_box_score_path)
      end
    else
      flash[:notice] = t('.file_type_flash')
      redirect_back(fallback_location: new_user_box_score_path)
    end
  end

  private

  def export_to_csv
    # EXAMPLE from https://www.freecodecamp.org/news/export-a-database-table-to-csv-using-a-simple-ruby-script-2/
    # file = "#{Rails.root}/public/data.csv"
    file = Rails.root.join('public', 'data.csv')
    table = User.all;0 # ";0" stops output.  Change "User" to any model.
    CSV.open(file, 'w') do |writer|
      # table headers
      writer << table.first.attributes.map { |a, _v| a }
      table.each do |s|
        writer << s.attributes.map { |_a, v| v }
      end
    end
  end

  def league_table_to_csv(round)
    file = "#{Rails.root}/public/data.csv"
    user_box_scores = rank_players(round.user_box_scores)
    table = user_box_scores;0 # ";0" stops output.
    CSV.open(file, 'w') do |writer|
      # table headers
      writer << [l(Time.now, format: :long),
                 t('.headers_line.player_header'),
                 t('.headers_line.rank_header'),
                 t('.headers_line.points_header'),
                 t('.headers_line.box_header'),
                 t('.headers_line.matches_played_header'),
                 t('.headers_line.matches_won_header'),
                 t('.headers_line.sets_played_header'),
                 t('.headers_line.sets_won_header')]
      table.each_with_index do |user_box_score, index|
        writer << [index + 1,
                   "#{user_box_score.user.first_name} #{user_box_score.user.last_name}",
                   user_box_score.rank,
                   user_box_score.points,
                   user_box_score.box.box_number,
                   user_box_score.games_played,
                   user_box_score.games_won,
                   user_box_score.sets_played,
                   user_box_score.sets_won]
      end
    end
    file
  end
end

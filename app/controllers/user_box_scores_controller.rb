class UserBoxScoresController < ApplicationController
  require "csv"

  def index
    # displays the league table, allows user to sort the table by headers clicks
    set_club_round

    # @order dictates the sorting order of the selected header
    # it is passed from the partial _header_to_link.html.erb when a header is clicked
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
    when "1" # "Player first name"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| [user_box_scores.user.first_name, -@order * user_box_scores.rank] }
      @user_box_scores.reverse! if @order == 1
    when "2" # "Player last name"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| [user_box_scores.user.last_name, -@order * user_box_scores.rank] }
      @user_box_scores.reverse! if @order == 1
    when "4" # "Points"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| [@order * user_box_scores.points, -@order * user_box_scores.rank] }
    when "5" # "Box"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| [-@order * user_box_scores.box.box_number, -@order * user_box_scores.rank] }
    when "6" # "Matches Played"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| [@order * user_box_scores.games_played, -@order * user_box_scores.rank] }
    when "7" # "Matches Won"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| [@order * user_box_scores.games_won, -@order * user_box_scores.rank] }
    when "8" # "Sets Played"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| [@order * user_box_scores.sets_played, -@order * user_box_scores.rank] }
    when "9" # "Sets Won"
      @user_box_scores = @round.user_box_scores.sort_by { |user_box_scores| [@order * user_box_scores.sets_won, -@order * user_box_scores.rank] }
    end
    @render_to_text = false
    if params[:to_text] == "true"
      @render_to_text = true
      create_txt
    end
  end

  def new
  end

  def create
    # (admin only) add a new club, its courts, players (given in a csv file), a round, its boxes and user_box_scores.
    # The csv file must contain the following fields:
    #         id, email, first_name, last_name, nickname, phone_number, role (player or referee)
    # Players are allocated in boxes by id (in descending order).
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
          boxes << Box.create(round_id: round.id, box_number: box_index + 1, chatroom_id: @general_chatroom.id)
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

  def league_table_to_csv
    # export the league table to a csv file
    # code inspired by https://www.freecodecamp.org/news/export-a-database-table-to-csv-using-a-simple-ruby-script-2/
    round = Round.find_by(start_date: params[:round_start].to_time,
                          club_id: Club.find_by(name: params[:club_name]).id)
    # file = Rails.root.join('public', 'data.csv')
    file = "#{Rails.root}/public/data.csv"
    user_box_scores = rank_players(round.user_box_scores)
    table = user_box_scores;0 # ";0" stops output.
    CSV.open(file, 'w') do |writer|
      # table headers
      writer << [l(Time.now, format: :short), # to time stamp the csv file
                 t('.table_headers.player_header'),
                 t('.table_headers.rank_header'),
                 t('.table_headers.points_header'),
                 t('.table_headers.box_header'),
                 t('.table_headers.matches_played_header'),
                 t('.table_headers.matches_won_header'),
                 t('.table_headers.sets_played_header'),
                 t('.table_headers.sets_won_header')]
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
    download_csv(file.pathmap)
  end

  private

  def download_csv(file = "#{Rails.root}/public/data.csv")
    if File.exist?(file)
      send_file file, filename: "league-table-#{Date.today}.csv", disposition: 'attachment', type: 'text/csv'
    end
  end

  def create_txt
    # from https://stackoverflow.com/questions/7414267/strip-html-from-string-ruby-on-rails
    # strip all html
    html_free_string = ActionView::Base.full_sanitizer.sanitize(render_to_string.encode("UTF-8"))
    send_data(html_free_string, template: :raw, filename: "league-table-#{Date.today}.txt", type: "text/txt")
  end
end

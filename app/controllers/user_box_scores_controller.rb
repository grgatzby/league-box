class UserBoxScoresController < ApplicationController
  require "csv"

  def index
    # displays the league table for the round, allows user to sort the table by click on headers
    set_club_round
    # @order dictates the sorting order of the selected header
    # it is passed from the partial _header_to_link.html.erb when a header is clicked
    if params[:order] && (params[:exsort] == params[:sort])
      @order = params[:order].to_i
    else
      @order = -1
    end
    if @round
      # by default: sort player by rank
      @user_box_scores = rank_players(@round.user_box_scores)
      @user_box_scores.reverse! if @order == 1

      @sort = params[:sort]
      case params[:sort]
      when "1" # "Player first name"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [user_bs.user.first_name, -@order * user_bs.rank] }
        @user_box_scores.reverse! if @order == 1
      when "2" # "Player last name"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [user_bs.user.last_name, -@order * user_bs.rank] }
        @user_box_scores.reverse! if @order == 1
      when "3" # "Ranking: default sorting order"
      when "4" # "Points"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [@order * user_bs.points, -@order * user_bs.rank] }
      when "5" # "Box"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [-@order * user_bs.box.box_number, -@order * user_bs.rank] }
      when "6" # "Matches Played"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [@order * user_bs.matches_played, -@order * user_bs.rank] }
      when "7" # "Matches Won"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [@order * user_bs.matches_won, -@order * user_bs.rank] }
      when "8" # "Sets Played"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [@order * user_bs.sets_played, -@order * user_bs.rank] }
      when "9" # "Sets Won"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [@order * user_bs.sets_won, -@order * user_bs.rank] }
      when "10" # "Games Played"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [@order * user_bs.games_played, -@order * user_bs.rank] }
      when "11" # "Games Won"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [@order * user_bs.games_won, -@order * user_bs.rank] }
      end
    end
    @render_to_text = false
    if params[:to_text] == "true"
      @render_to_text = true
      create_txt
    end
  end

  def index_year
    # displays the league table for the year, allows user to sort the table by click on headers
    @year = params[:round_year].to_i
    @club = Club.find(params[:club_id].to_i)
    rounds = Round.where('extract(year  from start_date) = ?', @year).where(club_id: params[:club_id].to_i)
    @round = current_round(@club.id)
    if rounds.length.positive?
      users = User.where(club_id: params[:club_id].to_i, role: "player")

      @user_box_scores = league_table_year(rounds, users)
      # @order dictates the sorting order of the selected header
      # it is passed from the partial _header_to_link.html.erb when a header is clicked
      if params[:order] && (params[:exsort] == params[:sort])
        @order = params[:order].to_i
      else
        @order = -1
      end

      @user_box_scores = rank_players(@user_box_scores, "index_year")
      @user_box_scores.sort_by! { |user_bs| -@order * user_bs[1][:rank] }
      @user_box_scores.each_with_index { |user_bs, index| user_bs[1][:index] = index }
      @sort = params[:sort]
      case params[:sort]
      when "1" # "Player first name"
        @user_box_scores.sort_by! { |user_bs| [user_bs[0].first_name, -@order * user_bs[1][:rank]] }
        @user_box_scores.reverse! if @order == 1
      when "2" # "Player last name"
        @user_box_scores.sort_by! { |user_bs| [user_bs[0].last_name, -@order * user_bs[1][:rank]] }
        @user_box_scores.reverse! if @order == 1
      when "3" # "Ranking: default sorting order"
      when "4" # "Points"
        @user_box_scores.sort_by! { |user_bs| [@order * user_bs[1][:points], -@order * user_bs[1][:rank]] }
      when "6" # "Matches Played"
        @user_box_scores.sort_by! { |user_bs| [@order * user_bs[1][:matches_played], -@order * user_bs[1][:rank]] }
      when "7" # "Matches Won"
        @user_box_scores.sort_by! { |user_bs| [@order * user_bs[1][:matches_won], -@order * user_bs[1][:rank]] }
      when "8" # "Sets Played"
        @user_box_scores.sort_by! { |user_bs| [@order * user_bs[1][:sets_played], -@order * user_bs[1][:rank]] }
      when "9" # "Sets Won"
        @user_box_scores.sort_by! { |user_bs| [@order * user_bs[1][:sets_won], -@order * user_bs[1][:rank]] }
      when "10" # "Games Played"
        @user_box_scores.sort_by! { |user_bs| [@order * user_bs[1][:games_played], -@order * user_bs[1][:rank]] }
      when "11" # "Games Won"
        @user_box_scores.sort_by! { |user_bs| [@order * user_bs[1][:games_won], -@order * user_bs[1][:rank]] }
      end
      @render_to_text = false
      if params[:to_text] == "true"
        @render_to_text = true
        create_txt
      end
    else
      flash[:notice] = t('.valid_year_flash')
      redirect_back(fallback_location: user_box_scores_path)
    end
  end

  def new
  end

  def create
    # (admin only) add a new club, its courts, players (given in a csv file), a round, its boxes and user_box_scores.
    # The csv file must contain the following fields:
    #      id, email, first_name, last_name, nickname, phone_number, role (player / referee)
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
                                sets_won: 0, sets_played: 0, matches_won: 0, matches_played: 0)
          end
        end
        redirect_to boxes_path(round_id: round.id, club_id: club.id)
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
    # credits https://www.freecodecamp.org/news/export-a-database-table-to-csv-using-a-simple-ruby-script-2/
    round = Round.find(params[:round_id])
    # file = Rails.root.join('public', 'data.csv')
    file = "#{Rails.root}/public/data.csv"
    user_box_scores = rank_players(round.user_box_scores)
    table = user_box_scores;0 # ";0" stops output.
    CSV.open(file, 'w') do |writer|
      # table headers
      writer << [l(Time.now, format: :short), # to time stamp the csv file
                 "player", "rank", "points", "box",
                 "matches played", "matches won", "sets played", "sets won", "games played", "games won"]
      table.each_with_index do |user_bs, index|
        writer << [index + 1,
                   "#{user_bs.user.first_name} #{user_bs.user.last_name}",
                   user_bs.rank, user_bs.points, user_bs.box.box_number,
                   user_bs.matches_played, user_bs.matches_won,
                   user_bs.sets_played, user_bs.sets_won,
                   user_bs.games_played, user_bs.games_won]
      end
    end
    download_csv(file.pathmap, "League Table-R#{round_number(round)}", round.club.name)
  end

  def league_year_to_csv
    # export the league table to a csv file
    # credits https://www.freecodecamp.org/news/export-a-database-table-to-csv-using-a-simple-ruby-script-2/
    year = params[:round_year].to_i
    rounds = Round.where('extract(year  from start_date) = ?', year).where(club_id: params[:club_id].to_i)
    users = User.where(club_id: params[:club_id].to_i, role: "player")
    # file = Rails.root.join('public', 'data.csv')
    file = "#{Rails.root}/public/data.csv"
    user_box_scores = league_table_year(rounds, users)
    user_box_scores = rank_players(user_box_scores, "index_year")
    table = user_box_scores;0 # ";0" stops output.
    CSV.open(file, 'w') do |writer|
      # table headers
      header = [l(Time.now, format: :short), # to time stamp the csv file
                "player", "rank", "points",
                "matches played", "matches won", "sets played", "sets won", "games played", "games won"]
        (1..rounds.size).each do |i|
          header.push("Rank_round#{i}")
          header.push("Points_round#{i}")
          header.push("Box_round#{i}")
        end
      writer << header
      table.each_with_index do |user_bs, index|
        data = [index + 1,
          "#{user_bs[0].first_name} #{user_bs[0].last_name}",
          user_bs[1][:rank], user_bs[1][:points],
          user_bs[1][:matches_played], user_bs[1][:matches_won],
          user_bs[1][:sets_played], user_bs[1][:sets_won],
          user_bs[1][:games_played], user_bs[1][:games_won]]
        (1..rounds.size).each do |i|
          data.push(user_bs[1]["rank_round#{i}"])
          data.push(user_bs[1]["points_round#{i}"])
          data.push(user_bs[1]["box_round#{i}"])
        end
        writer << data
      end
    end
    download_csv(file.pathmap, "League Table-#{year}", rounds[0].club.name)
  end

  private

  def create_txt
    # credits https://stackoverflow.com/questions/7414267/strip-html-from-string-ruby-on-rails
    # strip all html
    html_free_string = ActionView::Base.full_sanitizer.sanitize(render_to_string.encode("UTF-8"))
    send_data(html_free_string, template: :raw, filename: "league-table-#{Date.today}.txt", type: "text/txt")
  end

  def league_table_year(rounds, users)
    # return a hash : { player, { index, rank, points, matches_played, matches_won, games_played, games_won, sets_played, sets_won, last_round } }
    round_user_bss = rounds.sort_by(&:start_date).map(&:user_box_scores) # array of each round's array of user_box_scores in the year
    league_table = {}
    users.each do |user|
      league_table[user] =
        { # for each player, sum of points, matches_played, matches_won, games_played, games_won, sets_played, sets_won across the chosen year rounds
          index: 0,
          rank: 0, # updated in Application#rank_players
          points: round_user_bss.sum { |user_bss| user_bss.select { |user_bs| user_bs.user_id == user.id }.sum(&:points) },
          matches_played: round_user_bss.sum { |user_bss| user_bss.select { |user_bs| user_bs.user_id == user.id }.sum(&:matches_played) },
          matches_won: round_user_bss.sum { |user_bss| user_bss.select { |user_bs| user_bs.user_id == user.id }.sum(&:matches_won) },
          sets_played: round_user_bss.sum { |user_bss| user_bss.select { |user_bs| user_bs.user_id == user.id }.sum(&:sets_played) },
          sets_won: round_user_bss.sum { |user_bss| user_bss.select { |user_bs| user_bs.user_id == user.id }.sum(&:sets_won) },
          games_played: round_user_bss.sum { |user_bss| user_bss.select { |user_bs| user_bs.user_id == user.id }.sum(&:games_played) },
          games_won: round_user_bss.sum { |user_bss| user_bss.select { |user_bs| user_bs.user_id == user.id }.sum(&:games_won) },
          last_round: last_round(user)
        }
      # add the ranks, points and box of each round of the year for the player
      (1..rounds.size).each do |i|
        user_box_score = round_user_bss[i - 1].select { |user_bs| user_bs.user_id == user.id }[0]
        if user_box_score
          league_table[user]["rank_round#{i}"] = user_box_score.rank
          league_table[user]["points_round#{i}"] = user_box_score.points
          league_table[user]["box_round#{i}"] = user_box_score.box.box_number
        else
          league_table[user]["rank_round#{i}"] = 0
          league_table[user]["points_round#{i}"] = 0
          league_table[user]["box_round#{i}"] = 0
        end
      end
    end
    league_table
  end
end

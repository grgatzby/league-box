class UserBoxScoresController < ApplicationController
  require "csv"
  MIN_PLAYERS_PER_BOX = 4
  NEW_CLUB_HEADERS = ["email", "first_name", "last_name", "phone_number", "role"]
  CSV_LEAGUE_TABLE_HEADERS = ["player", "rank", "points",
    "matches played", "matches won", "sets played", "sets won", "games played", "games won"]
  ROUND_CSV_LEAGUE_TABLE_HEADERS = CSV_LEAGUE_TABLE_HEADERS + ["box_number"]
  REFEREE = ["referee", "player referee"]
  PLAYERS = ["player", "player referee"]
  PLAYERS_AND_SPARES = PLAYERS + ["spare"] # referee can play in lieu of missing player in a box as a 'spare' player
  # spare players do not appear ine the box league ranking

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
      case params[:sort].to_i
      when 1 # "Player first name"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [user_bs.user.first_name, -@order * user_bs.rank] }
        @user_box_scores.reverse! if @order == 1
      when 2 # "Player last name"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [user_bs.user.last_name, -@order * user_bs.rank] }
        @user_box_scores.reverse! if @order == 1
      when 3 # "Ranking: default sorting order"
      when 4 # "Points"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [@order * user_bs.points, -@order * user_bs.rank] }
      when 5 # "Box"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [-@order * user_bs.box.box_number, -@order * user_bs.rank] }
      when 6 # "Matches Played"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [@order * user_bs.matches_played, -@order * user_bs.rank] }
      when 7 # "Matches Won"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [@order * user_bs.matches_won, -@order * user_bs.rank] }
      when 8 # "Sets Played"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [@order * user_bs.sets_played, -@order * user_bs.rank] }
      when 9 # "Sets Won"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [@order * user_bs.sets_won, -@order * user_bs.rank] }
      when 10 # "Games Played"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [@order * user_bs.games_played, -@order * user_bs.rank] }
      when 11 # "Games Won"
        @user_box_scores = @round.user_box_scores.sort_by { |user_bs| [@order * user_bs.games_won, -@order * user_bs.rank] }
      end
    end
    @render_to_text = false
    if params[:to_text] == "true"
      @render_to_text = true
      create_txt
    end
  end

  def index_league
    set_club_round
    # displays the league table for the tournament (same club, same league_start), allows user to sort the table by click on headers
    @league_start = "#{params[:league_start]}".to_date
    club_id = params[:club_id].to_i
    @club = Club.find(club_id)
    @rounds = Round.where(league_start: @league_start, club_id:)
    @round = current_round(@club.id)
    if @rounds.length.positive?
      # users = User.where(club_id:, role: "player")
      users = User.where(club_id:)

      @user_box_scores = league_table(@rounds, users)
      # @order (1 or -1) determines the sorting order (ASC / DES) of the selected header
      # it is passed from the partial _header_to_link.html.erb when a header is clicked
      if params[:order] && (params[:exsort] == params[:sort])
        @order = params[:order].to_i
      else
        @order = -1
      end

      @user_box_scores = rank_players(@user_box_scores, "index_league")
      @user_box_scores.sort_by! { |user_bs| -@order * user_bs[1][:rank] }
      @user_box_scores.each_with_index { |user_bs, index| user_bs[1][:index] = index }
      @sort = params[:sort]
      case params[:sort].to_i
      when 1 # "Player first name"
        @user_box_scores.sort_by! { |user_bs| [user_bs[0].first_name, -@order * user_bs[1][:rank]] }
        @user_box_scores.reverse! if @order == 1
      when 2 # "Player last name"
        @user_box_scores.sort_by! { |user_bs| [user_bs[0].last_name, -@order * user_bs[1][:rank]] }
        @user_box_scores.reverse! if @order == 1
      when 3 # "Ranking: default sorting order"
      when 4 # "Points"
        @user_box_scores.sort_by! { |user_bs| [@order * user_bs[1][:points], -@order * user_bs[1][:rank]] }
      when 6 # "Matches Played"
        @user_box_scores.sort_by! { |user_bs| [@order * user_bs[1][:matches_played], -@order * user_bs[1][:rank]] }
      when 7 # "Matches Won"
        @user_box_scores.sort_by! { |user_bs| [@order * user_bs[1][:matches_won], -@order * user_bs[1][:rank]] }
      when 8 # "Sets Played"
        @user_box_scores.sort_by! { |user_bs| [@order * user_bs[1][:sets_played], -@order * user_bs[1][:rank]] }
      when 9 # "Sets Won"
        @user_box_scores.sort_by! { |user_bs| [@order * user_bs[1][:sets_won], -@order * user_bs[1][:rank]] }
      when 10 # "Games Played"
        @user_box_scores.sort_by! { |user_bs| [@order * user_bs[1][:games_played], -@order * user_bs[1][:rank]] }
      when 11 # "Games Won"
        @user_box_scores.sort_by! { |user_bs| [@order * user_bs[1][:games_won], -@order * user_bs[1][:rank]] }
      end
      @render_to_text = false
      if params[:to_text] == "true"
        @render_to_text = true
        create_txt
      end
    else
      flash[:notice] = t('.valid_league_flash')
      redirect_back(fallback_location: user_box_scores_path)
    end
  end

  def new
  end

  def create
    # (admin only) create a new club, its courts, players (given in a csv file), a round, its boxes and user_box_scores.
    # The csv file must contain the following fields:
    #      id, email, first_name, last_name, nickname, phone_number, role (player / referee / player referee / spare)
    # Players are allocated in boxes by id (in descending order).
    # The csv file may also contain the field box_number. Players are then allocated in the corresponding box.
    # TO DO: for each new box, the assigned chatroom is the #general chatroom which is later replaced with
    # a box chatroom when a player visits My Scores.

    csv_file = params[:csv_file]
    separator = params[:separator]
    if csv_file.content_type == "text/csv"
      headers = CSV.foreach(csv_file, col_sep: separator).first
      if headers.compact.map(&:downcase).sort - ["box_number"] == NEW_CLUB_HEADERS.sort
        box_players = [] # array (one per box) of array of box players
        boxes = [] # array of boxes
        # create club
        club = Club.create(name: params[:new_club_name])

        # create courts
        params[:nb_of_courts].to_i.times { |court_number| Court.create(name: court_number + 1, club_id: club.id) }

        # create first round
        round = Round.create(club_id: club.id,
                             start_date: params[:start_date].to_date,
                             end_date: params[:end_date].to_date,
                             league_start: params[:start_date].to_date)

        # create array of users (players and club referees)
        users = []
        box_numbers = []
        nb_spare = 0
        CSV.foreach(csv_file, headers: :first_row, header_converters: :symbol, col_sep: separator) do |row|
          if row[:role]
            if row[:box_number]
              if row[:role].downcase == "spare" # generate new e-mail address for spare player
                nb_spare += 1
                email = "spare#{format('%02d', nb_spare)}@club#{club.id}.com"
              else
                email = row[:email]
              end
              user = User.create(email:,
                                 first_name: row[:first_name], last_name: row[:last_name],
                                  phone_number: row[:phone_number], role: row[:role].downcase)

              box_numbers << row[:box_number].to_i

              # if user.role == "player" || user.role == "player referee" || user.role == "spare"
              if PLAYERS_AND_SPARES.include?(user.role)
                if box_players[row[:box_number].to_i]
                  box_players[row[:box_number].to_i] << user
                else
                  box_players[row[:box_number].to_i] = [user]
                end
              end
            else
              user = User.create(row)
            end
            user.update(club_id: club.id, password: "123456", nickname: user.nickname || (user.first_name + user.last_name[0]))
          end
          users << user if row[:email]
        end
        referees = users.select { |user| REFEREE.include?(user.role) }
        referees.each { |referee| referee.update(password: "654321") }
        players = users.select { |user| PLAYERS.include?(user.role) }

        # create boxes and user_box_scores
        if headers.include?("box_number")
          box_numbers = box_numbers.uniq.sort
          nb_boxes = box_numbers.count
          nb_boxes.times do |box_index|
            boxes << Box.create(round_id: round.id, box_number: box_numbers[box_index],
                                chatroom_id: @general_chatroom.id)

            box_players[box_numbers[box_index]].each do |player|
              UserBoxScore.create(user_id: player.id, box_id: boxes[box_index].id,
                                  points: 0, rank: 1,
                                  sets_won: 0, sets_played: 0,
                                  matches_won: 0, matches_played: 0,
                                  games_won: 0, games_played: 0)
            end
          end
          players_per_box = box_players[1].count
        else
          players_per_box = params[:players_per_box].to_i
          # if players_per_box > MIN_PLAYERS_PER_BOX, adjust down players_per_box so there are no less than 4 players per box
          players_per_box -= 1 while (players.count % players_per_box < MIN_PLAYERS_PER_BOX) && players_per_box > MIN_PLAYERS_PER_BOX
          nb_boxes = (players.count / players_per_box) + ((players.count % players_per_box) > MIN_PLAYERS_PER_BOX - 1 ? 1 : 0)
          nb_boxes.times do |box_index|
            boxes << Box.create(round_id: round.id, box_number: box_index + 1, chatroom_id: @general_chatroom.id)
            box_players << players.shift(players_per_box) # adds one array of box players
            box_players[box_index].each do |player|
              UserBoxScore.create(user_id: player.id, box_id: boxes[box_index].id,
                                  points: 0, rank: 1,
                                  sets_won: 0, sets_played: 0,
                                  matches_won: 0, matches_played: 0,
                                  games_won: 0, games_played: 0)
            end
          end
          if (players.count % players_per_box).positive?
            players.each(&:destroy) # destroy all remaining players (when less than MIN_PLAYERS_PER_BOX are left)
          end
        end
        flash[:notice] = t('.club_created', count: players.count % players_per_box, players: players_per_box)
        redirect_to boxes_path(round_id: round.id, club_id: club.id)
      else
        flash[:notice] = t('.header_flash')
        more_params = {
          new_club_name: params[:new_club_name],
          nb_of_courts: params[:nb_of_courts],
          players_per_box: params[:players_per_box],
          start_date: params[:start_date],
          end_date: params[:end_date]
        }
        redirect_to_back(more_params)
        # redirect_back(fallback_location: new_user_box_score_path)
      end
    else
      flash[:notice] = t('.file_type_flash')
      redirect_back(fallback_location: new_user_box_score_path)
    end
  end

  def round_league_table_to_csv
    # export the round league table to a csv file
    # credits https://www.freecodecamp.org/news/export-a-database-table-to-csv-using-a-simple-ruby-script-2/
    round = Round.find(params[:round_id])
    # file = Rails.root.join('public', 'data.csv')
    file = "#{Rails.root}/public/data.csv"
    user_box_scores = rank_players(round.user_box_scores)
    table = user_box_scores;0 # ";0" stops output.
    CSV.open(file, 'w') do |writer|
      # table headers
      writer << ([l(Time.now, format: :short)] + ROUND_CSV_LEAGUE_TABLE_HEADERS)
      table.each_with_index do |user_bs, index|
        writer << [index + 1,
                   "#{user_bs.user.first_name} #{user_bs.user.last_name}",
                   user_bs.rank, user_bs.points,
                   user_bs.matches_played, user_bs.matches_won,
                   user_bs.sets_played, user_bs.sets_won,
                   user_bs.games_played, user_bs.games_won,
                   user_bs.box.box_number]
      end
    end
    download_csv(file.pathmap, "League Table-R#{round_label(round)}", round.club.name)
  end

  def league_table_to_csv
    # export the league table to a csv file for the tournament (= collection of rounds with same league_start)
    league_start = params[:league_start].to_date
    club_id = params[:club_id].to_i
    # rounds = Round.where('extract(year  from start_date) = ?', year).where(club_id:)
    rounds = Round.where(league_start:, club_id:)
    # users = User.where(club_id:, role: "player")
    users = User.where(club_id:)
    file = "#{Rails.root}/public/data.csv"
    user_box_scores = league_table(rounds, users)
    user_box_scores = rank_players(user_box_scores, "index_league")
    table = user_box_scores;0 # ";0" stops output.
    CSV.open(file, 'w') do |writer|
      # table headers
      header = [l(Time.now, format: :short)] + LEAGUE_TABLE_HEADERS
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
    download_csv(file.pathmap, "League Table-T#{params[:league_start]}", rounds[0].club.name)
  end

  private

  def create_txt
    # credits https://stackoverflow.com/questions/7414267/strip-html-from-string-ruby-on-rails
    # strip all html
    html_free_string = ActionView::Base.full_sanitizer.sanitize(render_to_string.encode("UTF-8"))
    send_data(html_free_string, template: :raw, filename: "league-table-#{Date.today}.txt", type: "text/txt")
  end

  def league_table(rounds, users)
    # rounds is the collection of rounds in the tournament (same club, same league_start)
    # users is the collection of players in the club
    # return a hash : { player, { index, rank, points, matches_played, matches_won, games_played, games_won, sets_played, sets_won, last_round } }
    round_user_bss = rounds.sort_by(&:start_date).map(&:user_box_scores) # array of each round's array of user_box_scores in one tournament
    league_table = {}
    users.each do |user|
      league_table[user] =
        { # for each player, sum of points, matches_played, matches_won, games_played, games_won, sets_played, sets_won across the chosen league's rounds
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
      # add the ranks, points and box of each round of the league for the player
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

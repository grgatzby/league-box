class UserBoxScoresController < ApplicationController
  require "csv"
  def index
    set_club_and_round
    @user_box_scores = rank_players(@round.user_box_scores) if @round
    @rules = "A player's league position is determined by the total number of points won in a Round.
              In the event that two or more players have the same number of points the league position will be
              determined by:<br />
              1. Head to Head result (if only 2 players on the same score)<br />
              2. Most matches played<br />
              3. Ratio of Sets Won to Sets Played<br />
              4. Ratio of Games Won to Games Played"
  end

  def new
  end

  def create
    # allows the admin to create a club, its courts, players (from csv file), a round, its boxes and user_box_scores
    # the csv file must contain fields id, email, first_name, last_name, nickname, phone_number, role (players, referee)
    # players are allocated in boxes by id in descending order.

    csv_file = params[:csv_file]
    if csv_file.content_type == "text/csv"
      headers = CSV.foreach(csv_file).first
      if headers == ["id", "email", "first_name", "last_name", "nickname", "phone_number", "role"]
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

        # create array of users (players and a club referee)
        users = []
        CSV.foreach(csv_file, headers: :first_row, header_converters: :symbol) do |row|
          user = User.create(row)
          user.update(club_id: club.id, password: "123456")
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
        flash[:notice] = 'Your headers must be ["id", "email", "first_name", "last_name", "nickname", "phone_number", "role"].'
        redirect_back(fallback_location: new_user_box_score_path)
      end
    else
      flash[:notice] = "Please chose a csv type."
      redirect_back(fallback_location: new_user_box_score_path)
    end
  end

  private

  def rank_players(scores)
    @tieds = [] # populated in #add_to_tieds
    scores = scores.sort { |a, b| compare(a, b) }
    # updates the rank field in the UserBoxScore database

    # previous ranking (flawed), based on points only :

    # points_array = scores.map(&:points)
    # sorted_points = points_array.sort.uniq.reverse
    # scores.each do |score|
    #   score.update(rank: sorted_points.index(score.points) + 1)
    # end

    # new ranking based on sorting criterias and ties :

    rank_tied = 1
    player = scores.first
    ranks = scores.map do |score|
      rank_tied = scores.index(score) + 1 unless @tieds.include?(score) && compare(player, score).zero?
      player = score
      rank_tied
    end
    scores.each_with_index { |score, index| score.update(rank: ranks[index]) }
  end

  def compare(a, b)
    comparison = compare_points(a, b)
    return comparison unless comparison.zero?

    comparison = compare_matches_played(a, b)
    return comparison unless comparison.zero?

    comparison = compare_set_ratio(a, b)
    return comparison unless comparison.zero?

    comparison = compare_game_ratio(a, b)
    return comparison unless comparison.zero?

    add_to_tieds(a, b)

    comparison
  end

  def compare_points(a, b)
    b.points <=> a.points
  end

  def compare_matches_played(a, b)
    b.games_played <=> a.games_played
  end

  def compare_set_ratio(a, b)
    (b.sets_played.zero? ? 0 : b.sets_won.to_f / b.sets_played) <=> (a.sets_played.zero? ? 0 : a.sets_won.to_f / a.sets_played)
  end

  def compare_game_ratio(a, b)
    (b.games_played.zero? ? 0 : b.games_won.to_f / b.games_played) <=> (a.games_played.zero? ? 0 : a.games_won.to_f / a.games_played)
  end

  def add_to_tieds(*players)
    players.each { |player| @tieds << player }
    @tieds.uniq!
  end
end

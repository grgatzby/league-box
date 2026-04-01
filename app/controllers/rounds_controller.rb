# Rounds Controller
# Handles round creation, editing, and player promotion/relegation.
# Allows admin to create new rounds from CSV files or form-based player moves.
# Manages player movement between boxes based on performance (promotion/relegation).
class RoundsController < ApplicationController
  MIN_QUALIFYING_MATCHES = 2 # Minimum matches required to qualify for next round (otherwise move 99)
  MIN_PLAYERS_PER_BOX = 4
  NEW_ROUND_HEADERS = ["email", "first_name", "last_name", "phone_number", "role"].sort
  REFEREE = ["referee", "player referee"]
  PLAYERS = ["player", "player referee"]
  PLAYERS_AND_SPARES = PLAYERS + ["spare"]

  # Display form to create a new round (referees/admin only)
  # Pre-populates proposed moves from standings in each box (points, then rank):
  #   - 4 players per box: 1st +1 (except box 1), 2nd–3rd stay, last −1 (except last box)
  #   - more than 4: 1st +2 (clamped), 2nd +1, penultimate −1, last −2 (clamped); edges in box 1 / last box stay when needed
  #   - fewer than MIN_QUALIFYING_MATCHES matches: proposed move 99 (skip next round)
  # Default players/box = most common box size in the current round (overridable on submit).
  def new
    club_id = params[:club_id] ? params[:club_id].to_i : current_user.club_id
    @current_round = source_round_for_round_form(club_id)
    unless @current_round
      flash[:alert] = t(".no_round_flash", default: "No round found for this club.")
      redirect_to boxes_path(club_id: club_id)
      return
    end
    @boxes = @current_round.boxes.includes(:user_box_scores).sort_by(&:box_number)
    @new_round = Round.new
    @default_players_per_box = default_players_per_box_for_boxes(@boxes)

    @boxes.each do |box|
      new_box = @new_round.boxes.build
      sorted_ubs = box.user_box_scores.sort_by { |ubs| [-ubs.points.to_i, ubs.rank.to_i] }
      n = sorted_ubs.size
      nb_boxes = @boxes.size
      sorted_ubs.each_with_index do |ubs, idx|
        move = if ubs.matches_played.to_i < MIN_QUALIFYING_MATCHES
                 99
               else
                 proposed_promotion_move(
                   box: box,
                   box_index: box.box_number - 1,
                   nb_boxes: nb_boxes,
                   sorted_index: idx,
                   n_players: n
                 )
               end
        new_box.user_box_scores.build(promotion_move: move)
      end
    end
  end

  # Create a new round (admin only)
  # CSV upload (legacy) or form: moves + optional players_per_box (see create_round_from_form).
  def create
    csv_file = params[:round][:csv_file]
    delimiter = params[:delimiter].presence || ","
    if csv_file.present? && csv_file.content_type == "text/csv"
      create_round_from_csv_legacy(csv_file, delimiter)
    else
      create_round_from_form
    end
  end

  # Display form to edit round end_date (admin and referee only)
  # Only allows editing the most recent round's end_date
  # Validates that no matches were played after the new end_date
  def edit
    data = Club.all.includes(rounds: :boxes).as_json(
      include: { rounds: { only: [:id, :start_date, :end_date, :league_start] } })
    # transform the hash format convention {"round" => value} to {round: value} and exclude the sample club
    data.each(&:deep_symbolize_keys!).reject! { |a| a[:id] == @sample_club.id }
    @clubs = data.map { |club| club[:name] }
    params[:club] = current_user.club.name if REFEREE.include?(current_user.role)
    if params[:club]
      club_index = data.index { |club| club[:name] == params[:club] }
      club_id = Club.find_by(name: params[:club]).id
      rounds = data[club_index][:rounds].map { |round| [round[:league_start], round[:start_date]] }.sort
      # pick the last round in the most recent tournament
      @round = Round.find_by(start_date: rounds.last[1], club_id:)
      @last_round_match_date = last_round_match_date(@round)
    end
  end

  # Update round end_date (admin and referee only)
  # Validates that no matches were played after the proposed new end_date
  def update
    @round = Round.find(params[:id])
    # Validation: prevent changing end_date if matches were played after proposed date
    if last_round_match_date(@round) > params[:round][:end_date].to_date
      flash[:alert] = "Some match have been played beyond the proposed end date" # Match
      render :edit, status: :unprocessable_entity
    else
      @round.update(round_params)
      redirect_to boxes_path(round_id: @round.id, club_id: @round.club_id)
    end
  end

  private

  # Same round the user was viewing on boxes#index: prefer explicit round_id, then session, then generic current_round.
  # Important when a club runs several concurrent formats (e.g. singles vs doubles): current_round(club_id) alone is ambiguous.
  def source_round_for_round_form(club_id)
    round = nil
    rid = params[:round_id].presence
    if rid.present? && rid.to_s.match?(/\A\d+\z/)
      round = Round.find_by(id: rid.to_i, club_id: club_id)
    end
    if round.nil?
      sr_id = session[:selected_tournament_round_id]
      if sr_id.present?
        sr = Round.find_by(id: sr_id)
        round = sr if sr&.club_id == club_id
      end
    end
    round ||= current_round(club_id) || Round.where(club_id: club_id).order(:start_date).last
    round
  end

  # Typical players per box: the most frequent count across boxes (ties → smaller size).
  # Avoids using box 1 alone when it has a different (e.g. larger) size than the rest.
  def default_players_per_box_for_boxes(boxes)
    sizes = boxes.map { |b| b.user_box_scores.size }
    return MIN_PLAYERS_PER_BOX if sizes.empty? || sizes.all?(&:zero?)

    tallied = sizes.tally
    best = tallied.max_by { |size, count| [count, -size] }
    [best.first, MIN_PLAYERS_PER_BOX].max
  end

  # Proposed move: +N = toward box 1 (lower box_number), −N = toward last box.
  def proposed_promotion_move(box:, box_index:, nb_boxes:, sorted_index:, n_players:)
    if n_players <= 4
      case sorted_index
      when 0
        box.box_number == 1 ? 0 : 1
      when n_players - 1
        box.box_number == nb_boxes ? 0 : -1
      else
        0
      end
    else
      penultimate = n_players - 2
      last = n_players - 1
      case sorted_index
      when 0
        if box.box_number == 1
          0
        else
          [2, box_index].min
        end
      when 1
        box.box_number == 1 ? 0 : 1
      when penultimate
        box.box_number == nb_boxes ? 0 : -1
      when last
        if box.box_number == nb_boxes
          0
        else
          -[2, nb_boxes - box.box_number].min
        end
      else
        0
      end
    end
  end

  # Builds next round from admin overrides: promotion_move per player (+2 … −2, 99) and players_per_box.
  def create_round_from_form
    club_id = params[:club_id] ? params[:club_id].to_i : current_user.club_id
    current_round = source_round_for_round_form(club_id)
    unless current_round
      flash[:alert] = t(".no_round_flash", default: "No round found for this club.")
      redirect_back(fallback_location: boxes_path(club_id: club_id))
      return
    end
    if current_round.doubles_format?
      flash[:alert] = t(".doubles_not_supported", default: "Creating the next round from this form is only available for singles leagues.")
      redirect_back(fallback_location: new_round_path(club_id: current_round.club_id, round_id: current_round.id))
      return
    end

    current_boxes = current_round.boxes.includes(user_box_scores: :user).sort_by(&:box_number)
    unless current_boxes.any?
      flash[:alert] = t(".no_boxes_flash", default: "No boxes in the current round.")
      redirect_back(fallback_location: boxes_path(round_id: current_round.id, club_id: current_round.club_id))
      return
    end

    default_ppb = default_players_per_box_for_boxes(current_boxes)
    players_per_box = params[:players_per_box].to_i
    players_per_box = default_ppb if players_per_box <= 0
    players_per_box = [players_per_box, MIN_PLAYERS_PER_BOX].max

    round_attrs = {
      club_id: current_round.club_id,
      start_date: params[:round][:start_date].to_date,
      end_date: params[:round][:end_date].to_date,
      league_start: params[:round][:league_start].to_date,
      tournament_format: current_round.tournament_format,
      tiebreak_points: current_round.tiebreak_points
    }

    boxes_params = params[:round][:boxes_attributes]&.to_unsafe_h || {}
    nb = current_boxes.size
    staging = []

    current_boxes.each_with_index do |box, box_index|
      sorted_ubs = box.user_box_scores.sort_by { |ubs| [-ubs.points.to_i, ubs.rank.to_i] }
      attrs = boxes_params[box_index.to_s] || {}
      ubs_attrs = attrs["user_box_scores_attributes"] || attrs[:user_box_scores_attributes] || {}

      sorted_ubs.each_with_index do |ubs, player_index|
        p = ubs_attrs[player_index.to_s] || {}
        shift = (p["promotion_move"] || p[:promotion_move] || p["box_id"] || p[:box_id]).to_i
        next if shift == 99

        target_index = (box_index - shift).clamp(0, nb - 1)
        staging << {
          user_id: ubs.user_id,
          points: ubs.points.to_i,
          rank: ubs.rank.to_i,
          target_box_index: target_index
        }
      end
    end

    staging.sort_by! { |s| [s[:target_box_index], -s[:points], s[:rank]] }
    user_ids = staging.map { |s| s[:user_id] }

    if user_ids.empty?
      flash[:alert] = t(".no_players_flash", default: "No players selected for the next round (all marked 99?).")
      redirect_back(fallback_location: new_round_path(club_id: current_round.club_id, round_id: current_round.id))
      return
    end

    new_round = Round.create!(round_attrs)

    groups = user_ids.each_slice(players_per_box).to_a
    groups.each_with_index do |uids, idx|
      box = Box.create!(round_id: new_round.id, box_number: idx + 1)
      uids.each_with_index do |uid, rnk|
        UserBoxScore.create!(
          user_id: uid,
          box_id: box.id,
          rank: rnk + 1,
          points: 0,
          sets_won: 0, sets_played: 0,
          matches_won: 0, matches_played: 0,
          games_won: 0, games_played: 0
        )
      end
    end

    flash[:notice] = t(".round_created_from_form",
                       default: "Next round created: %{boxes} boxes, up to %{ppb} players per box.",
                       boxes: groups.size,
                       ppb: players_per_box)
    redirect_to boxes_path(round_id: new_round.id, club_id: current_round.club_id)
  end

  # Legacy CSV import (previous behaviour). Creates users/boxes from CSV when headers match NEW_ROUND_HEADERS.
  def create_round_from_csv_legacy(csv_file, delimiter)
    csv_file.rewind if csv_file.respond_to?(:rewind)
    headers = CSV.foreach(csv_file, col_sep: delimiter).first
    if headers.compact.map(&:downcase).sort - ["box_number"] == NEW_ROUND_HEADERS
      club = Club.find(params[:club_id])
      last_round = club.rounds.order(:start_date).last
      box_players = {}
      boxes = []
      box_numbers = []
      players = nil
      users = []
      nb_spare = 0

      players_per_box = club.rounds.last.boxes.find_by(box_number: 1).user_box_scores.size
      round = Round.create!(
        club_id: params[:club_id],
        start_date: params[:round][:start_date].to_date,
        end_date: params[:round][:end_date].to_date,
        league_start: params[:round][:league_start].to_date,
        tournament_format: last_round&.tournament_format || "singles_tennis",
        tiebreak_points: last_round&.tiebreak_points
      )

      CSV.foreach(csv_file, headers: :first_row, header_converters: :symbol, col_sep: delimiter) do |row|
        if PLAYERS_AND_SPARES.include?(row[:role])
          if row[:box_number]
            if User.exists?(first_name: row[:first_name], last_name: row[:last_name])
              user = User.find_by(first_name: row[:first_name], last_name: row[:last_name])
            else
              if row[:role].downcase == "spare"
                nb_spare += 1
                email = "spare#{format('%02d', nb_spare)}@club.com"
              else
                email = row[:email]
              end
              user = User.create(email:,
                                 first_name: row[:first_name], last_name: row[:last_name],
                                 phone_number: row[:phone_number], role: row[:role].downcase)

            end
            box_numbers << row[:box_number].to_i
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

          user.update(club_id: params[:club_id], password: "123456", nickname: user.nickname || (user.first_name + user.last_name[0]))
          user.update(password: "654321") if REFEREE.include?(user.role)
          users << user
        end
      end

      players = users.select { |user| PLAYERS.include?(user.role) }

      csv_file.rewind if csv_file.respond_to?(:rewind)
      csv_headers = CSV.read(csv_file, headers: true, header_converters: :symbol, col_sep: delimiter).headers.map(&:to_s)
      if csv_headers.map(&:downcase).include?("box_number")
        box_numbers = box_numbers.uniq.sort
        nb_boxes = box_numbers.size
        nb_boxes.times do |box_index|
          boxes << Box.create!(round_id: round.id, box_number: box_numbers[box_index])

          box_players[box_numbers[box_index]].each do |player|
            UserBoxScore.create(user_id: player.id, box_id: boxes[box_index].id,
                                points: 0, rank: 1,
                                sets_won: 0, sets_played: 0,
                                matches_won: 0, matches_played: 0,
                                games_won: 0, games_played: 0)
          end
        end
        players_per_box = box_players[box_numbers[0]].size
      else
        players_per_box = params[:players_per_box].to_i
        players_per_box -= 1 while (players.size % players_per_box < MIN_PLAYERS_PER_BOX) && players_per_box > MIN_PLAYERS_PER_BOX
        nb_boxes = (players.size / players_per_box) + ((players.size % players_per_box) > MIN_PLAYERS_PER_BOX - 1 ? 1 : 0)
        box_players = []
        nb_boxes.times do |box_index|
          boxes << Box.create!(round_id: round.id, box_number: box_index + 1)
          box_players << players.shift(players_per_box)
          box_players[box_index].each do |player|
            UserBoxScore.create(user_id: player.id, box_id: boxes[box_index].id,
                                points: 0, rank: 1,
                                sets_won: 0, sets_played: 0,
                                matches_won: 0, matches_played: 0,
                                games_won: 0, games_played: 0)
          end
        end
      end
      flash[:notice] = t(".round_created", count: players.size % players_per_box, players: players_per_box)
      if (players.size % players_per_box).positive? && box_numbers.empty?
        players.each(&:destroy)
      end
      redirect_to boxes_path(round_id: round.id, club_id: club.id)
    else
      flash[:notice] = t(".header_flash")
      redirect_back(fallback_location: new_user_box_score_path)
    end
  end

  def round_params
    params.require(:round).permit(:end_date)
  end
end

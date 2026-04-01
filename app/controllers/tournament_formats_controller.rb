class TournamentFormatsController < ApplicationController
  require "csv"
  require "set"

  class TournamentFormatInputError < StandardError; end

  before_action :ensure_admin!

  CSV_HEADERS = %w[first_name last_name phone_number email].freeze
  DEFAULT_PASSWORD = "123456".freeze
  SINGLES_HEADERS = %w[first_name last_name phone_number email].freeze
  DOUBLES_HEADERS = %w[first_name1 last_name1 phone_number1 email1 first_name2 last_name2 phone_number2 email2].freeze
  SEPARATORS = {
    "dot" => ".",
    "comma" => ",",
    "semicolon" => ";"
  }.freeze

  def new
    @clubs = Club.where.not(id: @sample_club.id).order(:name)
    @form = default_form_values
    @available_formats = available_formats_for_club(@form[:club_id])
    setup_court_requirements!(@form)
    @players = []
  end

  def preview
    @clubs = Club.where.not(id: @sample_club.id).order(:name)
    @form = form_from_params
    @available_formats = available_formats_for_club(@form[:club_id])
    ensure_format_allowed!(@form[:tournament_format], @available_formats)
    setup_court_requirements!(@form)
    validate_courts_to_create!(@form)
    @players = build_players_from_csv(@form)
    assign_box_numbers!(@players, @form[:players_per_box].to_i)
    @players_by_box = @players.group_by { |p| p[:box_number] }
    @club_for_preview = Club.find_by(id: @form[:club_id])
    render :preview
  rescue TournamentFormatInputError, CSV::MalformedCSVError => e
    Rails.logger.error("[TournamentFormats#create] #{e.class}: #{e.message}")
    Rails.logger.error(Array(e.backtrace).first(10).join("\n"))
    flash.now[:alert] = e.message
    @players = []
    render :new, status: :unprocessable_entity
  end

  def create
    @clubs = Club.where.not(id: @sample_club.id).order(:name)
    @form = form_from_params
    @available_formats = available_formats_for_club(@form[:club_id])
    ensure_format_allowed!(@form[:tournament_format], @available_formats)
    setup_court_requirements!(@form)
    validate_courts_to_create!(@form)
    @players = players_from_preview_params
    assign_box_numbers!(@players, @form[:players_per_box].to_i)
    if @players.blank?
      flash.now[:alert] = t(".missing_players", default: "Please upload and validate at least one player.")
      render :new, status: :unprocessable_entity
      return
    end

    round = nil
    # After dropping boxes.chatroom_id, long-lived processes may keep stale column metadata.
    # Refresh once here so Box.create! targets current DB columns.
    Box.reset_column_information
    ActiveRecord::Base.transaction do
      club = Club.find(@form[:club_id])
      ensure_compatible_courts!(club, @form)
      round = Round.create!(
        club_id: club.id,
        start_date: @form[:league_start],
        end_date: @form[:first_round_end_date],
        league_start: @form[:league_start],
        tournament_format: @form[:tournament_format]
      )

      boxes = {}
      @players.group_by { |p| p[:box_number].to_i }.sort.each do |box_number, _|
        boxes[box_number] = Box.create!(
          round_id: round.id,
          box_number: box_number
        )
      end

      users_by_box = Hash.new { |h, k| h[k] = [] }
      users_by_team_key = Hash.new { |h, k| h[k] = [] }
      @players.each do |attrs|
        user = upsert_user_from_preview(attrs, club.id)
        box = boxes[attrs[:box_number].to_i]
        UserBoxScore.find_or_create_by!(user_id: user.id, box_id: box.id)
        users_by_box[box.id] << user
        users_by_team_key[[box.id, attrs[:team_key].presence || attrs[:index].to_s]] << user
      end

      create_doubles_teams!(round, users_by_team_key) if round.doubles_format?
    end

    flash[:notice] = t(".created", default: "New tournament created successfully.")
    redirect_to boxes_path(round_id: round.id, club_id: round.club_id, tournament_format: round.tournament_format)
  rescue TournamentFormatInputError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, CSV::MalformedCSVError => e
    @players_by_box = @players.group_by { |p| p[:box_number] }
    @club_for_preview = Club.find_by(id: @form[:club_id])
    flash.now[:alert] = e.message
    render :preview, status: :unprocessable_entity
  end

  private

  def ensure_admin!
    return if current_user == @admin

    redirect_to root_path, alert: t(".forbidden", default: "Unauthorized.")
  end

  def default_form_values
    club_id = params[:club_id].presence || session[:selected_tournament_club_id].presence
    available_formats = available_formats_for_club(club_id)
    {
      club_id: club_id,
      tournament_format: available_formats.first || "singles_tennis",
      players_per_box: 4,
      separator: "comma",
      league_start: Date.today,
      first_round_end_date: Date.today + 30.days,
      courts_to_create: nil
    }
  end

  def form_from_params
    club_id = params[:club_id].presence || params.dig(:tournament_setup, :club_id).presence
    available_formats = available_formats_for_club(club_id)
    requested_tf = params[:tournament_format].presence || params.dig(:tournament_setup, :tournament_format).presence
    tf = if requested_tf.present? && available_formats.include?(requested_tf)
           requested_tf
         else
           available_formats.first || "singles_tennis"
         end
    ppb = params[:players_per_box].presence || params.dig(:tournament_setup, :players_per_box).presence || 4
    sep = params[:separator].presence || params.dig(:tournament_setup, :separator).presence || "comma"
    league_start_raw = params[:league_start].presence || params.dig(:tournament_setup, :league_start).presence
    first_round_end_raw = params[:first_round_end_date].presence || params.dig(:tournament_setup, :first_round_end_date).presence
    courts_to_create_raw = params[:courts_to_create].presence || params.dig(:tournament_setup, :courts_to_create).presence

    {
      club_id: club_id,
      tournament_format: tf,
      players_per_box: ppb.to_i.clamp(3, 5),
      separator: sep,
      league_start: parse_date_or_default(league_start_raw, Date.today),
      first_round_end_date: parse_date_or_default(first_round_end_raw, Date.today + 30.days),
      courts_to_create: courts_to_create_raw.present? ? courts_to_create_raw.to_i : nil
    }
  end

  def build_players_from_csv(form)
    csv_file = params[:csv_file] || params.dig(:tournament_setup, :csv_file)
    return seed_players_from_club(form) unless csv_file

    separator = SEPARATORS[form[:separator].to_s] || ","
    rows = CSV.parse(csv_file.read, headers: true, col_sep: separator)
    headers = Array(rows.headers).compact.map { |h| h.to_s.strip }
    if headers.empty?
      raise TournamentFormatInputError, t(".invalid_headers", default: "Invalid CSV headers. Expected: first_name,last_name,phone_number,email")
    end
    if form[:tournament_format].to_s == "singles_tennis"
      parse_singles_rows(rows, headers)
    else
      parse_doubles_rows(rows, headers)
    end
  end

  def seed_players_from_club(form)
    club = Club.find_by(id: form[:club_id])
    raise TournamentFormatInputError, t("tournament_formats.common.missing_club", default: "Please select a club.") unless club

    users = club.users.where(role: %w[player player referee]).to_a.shuffle
    raise TournamentFormatInputError, t("tournament_formats.common.no_seed_players", default: "No existing players found in this club to seed from.") if users.blank?

    if form[:tournament_format].to_s == "singles_tennis"
      users.map.with_index do |user, idx|
        {
          index: idx,
          team_key: "single_#{idx}",
          existing_user_id: user.id,
          first_name: user.first_name.to_s.strip,
          last_name: user.last_name.to_s.strip,
          email: user.email.to_s.strip.downcase,
          phone_number: user.phone_number.to_s.strip,
          nickname: (user.nickname.presence || nickname_for(user.first_name, user.last_name))
        }
      end
    else
      if users.size < 2
        raise TournamentFormatInputError, t("tournament_formats.common.not_enough_seed_players_doubles", default: "At least 2 players are required to seed doubles/padel.")
      end

      seeded = []
      users.each_slice(2).with_index do |pair, idx|
        next if pair.size < 2

        pair.each do |user|
          seeded << {
            index: idx,
            team_key: "team_#{idx}",
            existing_user_id: user.id,
            first_name: user.first_name.to_s.strip,
            last_name: user.last_name.to_s.strip,
            email: user.email.to_s.strip.downcase,
            phone_number: user.phone_number.to_s.strip,
            nickname: (user.nickname.presence || nickname_for(user.first_name, user.last_name))
          }
        end
      end
      raise TournamentFormatInputError, t("tournament_formats.common.not_enough_seed_players_doubles", default: "At least 2 players are required to seed doubles/padel.") if seeded.blank?

      seeded
    end
  end

  def players_from_preview_params
    list = params[:players]
    return [] unless list

    list.values.map do |raw|
      {
        existing_user_id: raw[:existing_user_id].presence,
        index: raw[:index].to_i,
        team_key: raw[:team_key].to_s,
        box_number: raw[:box_number].to_i,
        first_name: raw[:first_name].to_s.strip,
        last_name: raw[:last_name].to_s.strip,
        nickname: raw[:nickname].to_s.strip,
        email: raw[:email].to_s.strip.downcase,
        phone_number: raw[:phone_number].to_s.strip
      }
    end
  end

  def assign_box_numbers!(players, players_per_box)
    return if players.blank?

    team_keys_in_order = players.map { |p| p[:team_key].presence || p[:index].to_s }.uniq
    # In doubles/padel, the form value is "teams per box" (not players per box).
    teams_per_box = [players_per_box.to_i, 1].max
    team_box_map = {}
    team_keys_in_order.each_with_index { |team_key, idx| team_box_map[team_key] = (idx / teams_per_box) + 1 }

    players.each_with_index do |player, index|
      next if player[:box_number].to_i > 0

      team_key = player[:team_key].presence || player[:index].to_s
      player[:box_number] = if @form[:tournament_format].to_s == "singles_tennis"
                              (index / players_per_box) + 1
                            else
                              team_box_map[team_key]
                            end
    end
  end

  def nickname_for(first_name, last_name)
    fn = first_name.to_s.strip
    ln = last_name.to_s.strip
    return "" if fn.blank? && ln.blank?

    "#{fn.capitalize}#{ln.first.to_s.upcase}"
  end

  def upsert_user_from_preview(attrs, club_id)
    user = if attrs[:existing_user_id].present?
             User.find_by(id: attrs[:existing_user_id]) || User.find_by(email: attrs[:email])
           else
             User.find_by(email: attrs[:email])
           end

    if user
      user.update!(
        club_id: club_id,
        first_name: attrs[:first_name],
        last_name: attrs[:last_name],
        nickname: attrs[:nickname].presence || nickname_for(attrs[:first_name], attrs[:last_name]),
        phone_number: attrs[:phone_number]
      )
      return user
    end

    User.create!(
      club_id: club_id,
      role: "player",
      email: attrs[:email],
      first_name: attrs[:first_name],
      last_name: attrs[:last_name],
      phone_number: attrs[:phone_number],
      nickname: attrs[:nickname].presence || nickname_for(attrs[:first_name], attrs[:last_name]),
      password: DEFAULT_PASSWORD
    )
  end

  def create_doubles_teams!(round, users_by_team_key)
    users_by_team_key.each do |(box_id, _team_key), users|
      next if users.empty?

      box = Box.find(box_id)
      team = Team.create!(round_id: round.id, box_id: box.id, name: users.map(&:last_name).join(" / "))
      users.each { |user| TeamMembership.find_or_create_by!(team_id: team.id, user_id: user.id) }
      TeamBoxScore.find_or_create_by!(team_id: team.id, box_id: box.id)
    end
  end

  def available_formats_for_club(club_id)
    return Round::TOURNAMENT_FORMATS if club_id.blank?

    club = Club.find_by(id: club_id)
    return Round::TOURNAMENT_FORMATS unless club

    existing = club.rounds.distinct.pluck(:tournament_format)
    Round::TOURNAMENT_FORMATS - existing
  end

  def ensure_format_allowed!(format, available_formats)
    return if available_formats.include?(format.to_s)

    raise TournamentFormatInputError, t(".format_unavailable", default: "This tournament format already exists for the selected club.")
  end

  def parse_date_or_default(raw, default_date)
    return default_date if raw.blank?

    Date.parse(raw.to_s)
  rescue ArgumentError, Date::Error
    raise TournamentFormatInputError, t("tournament_formats.common.invalid_date", default: "Invalid date format.")
  end

  def setup_court_requirements!(form)
    club = Club.find_by(id: form[:club_id])
    @required_court_kind = Court.kind_for_tournament_format(form[:tournament_format])
    @existing_compatible_courts_count = club ? club.courts.where(court_kind: @required_court_kind).count : 0
    @needs_courts_input = club.present? && @existing_compatible_courts_count.zero?
  end

  def validate_courts_to_create!(form)
    if form[:first_round_end_date] < form[:league_start]
      raise TournamentFormatInputError, t("tournament_formats.common.invalid_round_dates", default: "First round end date must be on or after league start date.")
    end
    return unless @needs_courts_input
    return if form[:courts_to_create].to_i.positive?

    raise TournamentFormatInputError, t("tournament_formats.common.missing_courts_to_create", default: "Please enter how many courts to create for this format.")
  end

  def ensure_compatible_courts!(club, form)
    kind = Court.kind_for_tournament_format(form[:tournament_format])
    return if club.courts.where(court_kind: kind).exists?

    number = form[:courts_to_create].to_i
    if number <= 0
      raise TournamentFormatInputError, t("tournament_formats.common.missing_courts_to_create", default: "Please enter how many courts to create for this format.")
    end

    existing_names = club.courts.pluck(:name).to_set
    created = 0
    cursor = 1
    while created < number
      name = kind == "padel" ? "#{cursor}P" : cursor.to_s
      cursor += 1
      next if existing_names.include?(name)

      Court.create!(club_id: club.id, name: name, court_kind: kind)
      existing_names << name
      created += 1
    end
  end

  def parse_singles_rows(rows, headers)
    unless headers.sort == SINGLES_HEADERS.sort
      raise TournamentFormatInputError, t(".invalid_headers", default: "Invalid CSV headers. Expected: first_name,last_name,phone_number,email")
    end

    rows.map.with_index do |row, idx|
      email = row["email"].to_s.strip.downcase
      raise TournamentFormatInputError, t(".missing_email", default: "Each player must have an email.") if email.blank?

      first_name = row["first_name"].to_s.strip
      last_name = row["last_name"].to_s.strip
      existing = User.find_by(email: email)
      {
        index: idx,
        team_key: "single_#{idx}",
        existing_user_id: existing&.id,
        first_name: first_name,
        last_name: last_name,
        email: email,
        phone_number: row["phone_number"].to_s.strip,
        nickname: nickname_for(first_name, last_name)
      }
    end
  end

  def parse_doubles_rows(rows, headers)
    unless headers.sort == DOUBLES_HEADERS.sort
      raise TournamentFormatInputError, t(".invalid_doubles_headers", default: "Invalid CSV headers for doubles/padel.")
    end

    players = []
    rows.each_with_index do |row, idx|
      [
        {
          first_name: row["first_name1"],
          last_name: row["last_name1"],
          phone_number: row["phone_number1"],
          email: row["email1"]
        },
        {
          first_name: row["first_name2"],
          last_name: row["last_name2"],
          phone_number: row["phone_number2"],
          email: row["email2"]
        }
      ].each do |player_row|
        email = player_row[:email].to_s.strip.downcase
        raise TournamentFormatInputError, t(".missing_email", default: "Each player must have an email.") if email.blank?

        first_name = player_row[:first_name].to_s.strip
        last_name = player_row[:last_name].to_s.strip
        existing = User.find_by(email: email)
        players << {
          index: idx,
          team_key: "team_#{idx}",
          existing_user_id: existing&.id,
          first_name: first_name,
          last_name: last_name,
          email: email,
          phone_number: player_row[:phone_number].to_s.strip,
          nickname: nickname_for(first_name, last_name)
        }
      end
    end
    players
  end
end

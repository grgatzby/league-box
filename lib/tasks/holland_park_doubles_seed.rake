# frozen_string_literal: true

namespace :seed do
  desc <<-DESC.squish
    Seed Holland Park LTC padel tournament: 6 boxes × 4 pairs (48 players).
    Default club_id=73. ENV: SEED=int (random), CLUB_ID=int.
    Ensures all users with last name "Mardinian" (case-insensitive) in that club are included.
  DESC
  task holland_park_padel: :environment do
    rng_seed = ENV.fetch("SEED", Random.new_seed).to_i
    srand(rng_seed)

    club_id = ENV.fetch("CLUB_ID", "73").to_i
    club = Club.find(club_id)

    season_start = Date.current.beginning_of_month
    season_end = season_start.next_month.next_month.end_of_month

    round = Round.find_or_initialize_by(
      club_id: club.id,
      start_date: season_start,
      tournament_format: "doubles_padel"
    )
    round.end_date = season_end
    round.league_start = season_start
    round.save!

    # Boxes destroy teams (and matches, team_box_scores, etc.) via dependent associations
    round.boxes.destroy_all

    required_players = 48 # 6 boxes × 4 teams × 2 players
    teams_per_box = 4

    mandatory_mardinians = User.where(club_id: club.id).where("LOWER(last_name) = ?", "mardinian").to_a

    if mandatory_mardinians.size > required_players
      abort "Cannot seed: #{mandatory_mardinians.size} users named Mardinian but only #{required_players} slots."
    end

    club_players = User.where(club_id: club.id, role: %w[player player referee]).to_a
    players_pool = (mandatory_mardinians + club_players).uniq

    first_names = %w[
      Liam Noah Oliver Elijah James Lucas Mason Ethan Alexander Henry
      Sophia Emma Charlotte Amelia Ava Isabela Mia Harper Evelyn Scarlett
      Arthur Leo Jules Hugo Louis Adam Gabriel Nathan Theo Antoine
    ]
    last_names = %w[
      Taylor Smith Wilson Moore Anderson Martin Jackson Thompson White Harris
      Brown Clark Walker Young King Hall Allen Scott Wright Green Baker
    ]

    while players_pool.size < required_players
      first_name = first_names.sample
      last_name = last_names.sample
      email = "hpltc.padel.#{first_name.downcase}.#{last_name.downcase}.#{SecureRandom.hex(3)}@club.be"
      phone = format("+447700%06d", rand(1_000_000))
      nickname = "#{first_name}#{last_name[0]}"

      players_pool << User.create!(
        email: email,
        first_name: first_name,
        last_name: last_name,
        nickname: nickname,
        phone_number: phone,
        password: "123456",
        role: "player",
        club_id: club.id
      )
    end

    others = (players_pool - mandatory_mardinians).shuffle
    fill_count = required_players - mandatory_mardinians.size
    selected_players = mandatory_mardinians + others.first(fill_count)
    selected_players.shuffle!

    pairs = selected_players.each_slice(2).to_a
    if pairs.size != 24
      abort "Expected 24 pairs from #{required_players} players, got #{pairs.size}."
    end

    pairs.each_slice(teams_per_box).with_index(1) do |teams_slice, box_number|
      chatroom = Chatroom.find_or_create_by!(
        name: "#{club.name} - PadelSeed-R#{round.id}:B#{format('%02d', box_number)}"
      )
      box = Box.create!(round_id: round.id, box_number: box_number, chatroom_id: chatroom.id)

      teams_slice.each_with_index do |pair, team_index|
        team = Team.create!(
          round_id: round.id,
          box_id: box.id,
          name: "B#{format('%02d', box_number)}-T#{team_index + 1}"
        )
        pair.each do |player|
          TeamMembership.find_or_create_by!(team_id: team.id, user_id: player.id)
          UserBoxScore.find_or_create_by!(user_id: player.id, box_id: box.id) do |ubs|
            ubs.points = 0
            ubs.rank = 1
            ubs.sets_won = 0
            ubs.sets_played = 0
            ubs.matches_won = 0
            ubs.matches_played = 0
            ubs.games_won = 0
            ubs.games_played = 0
          end
        end

        TeamBoxScore.find_or_create_by!(team_id: team.id, box_id: box.id) do |tbs|
          tbs.points = 0
          tbs.rank = 1
          tbs.sets_won = 0
          tbs.sets_played = 0
          tbs.matches_won = 0
          tbs.matches_played = 0
          tbs.games_won = 0
          tbs.games_played = 0
        end
      end
    end

    mardinians_in_round = User.joins(team_memberships: { team: :round })
                              .where(rounds: { id: round.id })
                              .where("LOWER(users.last_name) = ?", "mardinian")
                              .distinct

    puts "Seed complete (padel)."
    puts "Club: #{club.id} — #{club.name}"
    puts "Round: #{round.id} (#{round.tournament_format})"
    puts "Boxes: #{round.boxes.count}, Teams: #{round.teams.count}"
    puts "Mardinian users in this round: #{mardinians_in_round.count}"
    puts "Random seed used: #{rng_seed}"
  end

  desc "Alias for seed:holland_park_padel (same padel seed)"
  task holland_park_doubles: :holland_park_padel
end

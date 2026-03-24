# frozen_string_literal: true

namespace :data_fixes do
  desc "Replace users 48 and 26 in team 80 with sampled eligible users"
  task replace_team_80_members: :environment do
    team = Team.includes(:round, :users).find_by(id: 80)
    raise "Team 80 not found." unless team
    raise "Team 80 has no round." unless team.round

    round = team.round
    club_id = round.club_id
    round_id = round.id
    target_user_ids = [48, 26]

    TeamMembership.transaction do
      TeamMembership.where(team_id: team.id, user_id: target_user_ids).delete_all

      excluded_ids = target_user_ids + team.users.pluck(:id)
      replacement_ids = User
        .where(club_id: club_id, role: ["player", "player referee"])
        .where.not(id: excluded_ids.uniq)
        .order(Arel.sql("RANDOM()"))
        .limit(2)
        .pluck(:id)
        .uniq

      raise "Not enough replacement users in club #{club_id}." if replacement_ids.size < 2

      replacement_ids.each do |user_id|
        existing_in_round = TeamMembership
          .joins(:team)
          .where(user_id: user_id, teams: { round_id: round_id })
          .first

        if existing_in_round
          existing_in_round.update!(team_id: team.id)
        else
          TeamMembership.create!(team_id: team.id, user_id: user_id)
        end
      end

      team.reload
      last_names = team.users.map(&:last_name).compact.map(&:strip).reject(&:empty?).sort
      team.update!(name: last_names.join(" / ")) if last_names.any?
    end

    team.reload
    puts "Team #{team.id} updated."
    puts "Current name: #{team.name}"
    puts "Members: #{team.users.map { |u| "#{u.id} #{u.first_name} #{u.last_name}" }.join(", ")}"
  end

  desc "Ensure teams 69 and 70 have 2 members by creating one random user per missing slot"
  task fill_teams_69_70_with_random_users: :environment do
    team_ids = [69, 70]

    TeamMembership.transaction do
      team_ids.each do |team_id|
        team = Team.includes(:round, :users).find_by(id: team_id)
        raise "Team #{team_id} not found." unless team
        raise "Team #{team_id} has no round." unless team.round

        missing_slots = 2 - team.users.size
        next if missing_slots <= 0

        missing_slots.times do
          user = User.create!(
            club_id: team.round.club_id,
            role: "player",
            email: "auto.team#{team_id}.#{SecureRandom.hex(4)}@league-box.local",
            first_name: "Auto",
            last_name: "Team#{team_id}",
            nickname: "AutoT#{team_id}",
            phone_number: format("+3306%08d", rand(100_000_000)),
            password: "123456"
          )
          TeamMembership.create!(team_id: team.id, user_id: user.id)
        end

        team.reload
        last_names = team.users.map(&:last_name).compact.map(&:strip).reject(&:empty?).sort
        team.update!(name: last_names.join(" / ")) if last_names.any?

        puts "Team #{team.id} now has #{team.users.size} members."
        puts "Members: #{team.users.map { |u| "#{u.id} #{u.first_name} #{u.last_name}" }.join(', ')}"
      end
    end
  end
end

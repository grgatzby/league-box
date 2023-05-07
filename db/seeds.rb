# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

require 'faker'

# set as true to append new round to existing clubs
new_round = false

if true
  # if Rails.env.development?
    puts "-------------------"
    puts "reseting Database"
    puts "-------------------"
    Club.destroy_all
    Round.destroy_all
    Court.destroy_all
    Match.destroy_all
    Box.destroy_all
    UserBoxScore.destroy_all
    UserMatchScore.destroy_all
    User.destroy_all
  # end

  puts "-------------------"
  puts "seeding Clubs"
  puts "-------------------"
  sample_club = Club.create(
    name: "My tennis club"
  )

  Club.create(
    name: "Wimbledon Ltc Club"
  )
  Club.create(
    name: "Holland Park Ltc Club"
  )

  User.create(
    email: "guillaume.cazals@club.be",
    first_name: "Guillaume",
    last_name: "Cazals",
    nickname: "GuillaumeC",
    phone_number: "+32470970853",
    password: "650702",
    role: "admin",
    club_id: sample_club.id  # user needs to belong to a club
  )

  clubs = Club.all.reject { |club| club == sample_club }

  clubs.each do |club|
    puts "seeding current round for #{club.name}"
    puts "------------------------------------"
    round = Round.create(
      start_date: Date.new(2023, 4, 1),
      end_date: Date.new(2023, 6, 30),
      club_id: club.id
    )
    puts "-> round created"

    puts "seeding a manager for #{club.name}"
    puts "------------------------------------"
    first_name = Faker::Name.male_first_name
    last_name = Faker::Name.last_name
    nickname = first_name + last_name[0]
    user = User.create(
      first_name: first_name,
      last_name: last_name,
      nickname: nickname,
      email: "#{first_name.downcase}.#{last_name.downcase}@club.be",
      phone_number: Faker::PhoneNumber.cell_phone,
      password: "654321",
      club_id: club.id,
      role: "manager"
    )

    puts "-> manager created: #{user.email}"

    14.times do |box_number|
      puts "seeding box #{box_number + 1} for #{club.name}"
      puts "------------------------------------"
      box = Box.create(
        round_id: round.id,
        box_number: box_number + 1
      )

      puts "seeding 6 players and their User-box-score for box #{box_number + 1}"
      puts "------------------------------------"

      6.times do
        # generate 6 random players in the box
        first_name = Faker::Name.male_first_name
        last_name = Faker::Name.last_name
        nickname = first_name + last_name[0]

        user = User.create(
          first_name: first_name,
          last_name: last_name,
          nickname: nickname,
          email: "#{first_name.downcase}.#{last_name.downcase}@club.be",
          phone_number: Faker::PhoneNumber.cell_phone,
          password: "123456",
          club_id: club.id,
          role: "player"
        )

        UserBoxScore.create(
          user_id: user.id,
          box_id: box.id,
          points: 0,
          rank: 0,
          sets_won: 0,
          sets_played: 0,
          games_won: 0,
          games_played: 0
        )
        puts "  -> player and UserBoxScore created: #{user.email}"
      end
    end

    puts "seeding 10 courts for #{club.name}"
    puts "------------------------------------"
    10.times do |court_number|
      Court.create(
        name: court_number + 1,
        club_id: club.id
      )
    end
    puts "  -> 10 courts created"
  end

new_round = true

if new_round
  sample_club = Club.find_by(name: "My tennis club")
  clubs = Club.all.reject { |club| club == sample_club }

  clubs.each do |club|
    puts "seeding current round for #{club.name}"
    puts "------------------------------------"
    round = Round.create(
      start_date: Date.new(2023, 1, 1),
      end_date: Date.new(2023, 3, 31),
      club_id: club.id
    )
    puts "-> new round created"

    sourcing_round = Round.find_by(
      start_date: Date.new(2023, 4, 1),
      club_id: club.id
    )
    sourcing_boxes = Box.where(round_id: sourcing_round.id)

    14.times do |box_number|
      puts "seeding box #{box_number + 1} for #{club.name}"
      puts "------------------------------------"
      box = Box.create(
        round_id: round.id,
        box_number: box_number + 1
      )

      matching_box = Box.find_by(
        round_id: sourcing_round.id,
        box_number: box.box_number
      )

      puts "UserBoxScores for box #{box_number + 1}"
      puts "------------------------------------"

      matching_box.user_box_scores.each do |ubs|
        new_ubs = UserBoxScore.create(
          user_id: ubs.user_id,
          box_id: box.id,
          points: 0,
          rank: 0,
          sets_won: 0,
          sets_played: 0,
          games_won: 0,
          games_played: 0
        )
        puts "  -> UserBoxScore created for #{new_ubs.user.email}"
      end
    end
  end
end

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

require 'faker'

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
Club.create(
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
  role: "admin"
)

clubs = Club.all.reject { |club| club.name == "My tennis club" }

clubs.each do |club|
  round = Round.create(
    start_date: Date.new(2023, 4, 1),
    end_date: Date.new(2023, 6, 30),
    club_id: club.id
  )

  14.times do |box_number|
    puts "seeding box #{box_number}"
    box = Box.create(
      round_id: round.id,
      box_number: box_number + 1
    )

    puts "seeding a manager and 6 Users and their User-box-score"
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

    puts "-> #{user.email} manager created"

    puts "seeding 6 players and their User-box-score"

    6.times do
      # generate 6 random players in the box
      first_name = Faker::Name.male_first_name
      last_name = Faker::Name.last_name
      nickname = first_name + last_name[0]
      # Faker::Config.locale = 'fr-FR'

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

      puts "-> #{user.email} player created"

      UserBoxScore.create(
        user_id: user.id,
        box_id: box.id,
        points: 0,
        rank: 0
      )
      puts "  -> #{user.email} UserBoxScore created"
    end
  end

  10.times do |court_number|
    Court.create(
      name: court_number + 1,
      club_id: club.id
    )
  end
end

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

if Club.all.empty?
  puts "-------------------"
  puts "seeding Club"
  puts "-------------------"
  Club.create(
    name: "Your tennis club"
  )
  Club.create(
    name: "Wimbledon"
  )
end
club = Club.last

if User.all.empty?
  puts "-------------------"
  puts "seeding Users"
  puts "-------------------"

  User.create(
    email: "guillaume.cazals@club.be",
    first_name: "Guillaume",
    last_name: "Cazals",
    nickname: "GuillaumeC",
    phone_number: "+32470970853",
    password: "654321",
    club_id: club.id,
    is_manager: true
  )
end

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

  puts "seeding 6 Users and User-box-scores"
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
      phone_number: Faker::PhoneNumber.phone_number_with_country_code,
      password: "123456",
      club_id: club.id,
      is_manager: false
    )
    puts "-> #{user.email} created"
    UserBoxScore.create(
      user_id: user.id,
      box_id: box.id,
      points: 0,
      rank: 0
    )
  end
end

10.times do |court_number|
  Court.create(
    name: court_number + 1,
    club_id: club.id
  )
end

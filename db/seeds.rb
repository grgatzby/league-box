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
  puts "resetting Database"
  puts "-------------------"
  Round.destroy_all
  Court.destroy_all
  Box.destroy_all
  Match.destroy_all
  UserBoxScore.destroy_all
  UserMatchScore.destroy_all
  User.destroy_all
# end

if Club.all.empty?
  puts "-------------------"
  puts "seeding Club"
  puts "-------------------"
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
    first_name: "Guilaume",
    last_name: "Cazals",
    phone_number: "+32470970853",
    password: "654321",
    club_id: club.id,
    is_manager: true
  )
end

round = Round.create(
  start_date: Date.new(2023,1,1),
  end_date: Date.new(2023,3,31),
  club_id: club.id
)

14.times do |box_number|
  puts "seeding box #{box_number}"
  box = Box.create(
    round_id: round.id,
    box_number: box_number
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
      email: "#{first_name.downcase}.#{last_name.downcase}@club.be",
      phone_number: Faker::PhoneNumber.phone_number_with_country_code,
      password: "123456",
      club_id: club.id,
      is_manager: false
    )
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
    name: court_number,
    club_id: club.id
  )
end

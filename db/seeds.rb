# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

# require 'faker'

# # set as true to append new round to existing clubs
# new_round = false

# 1/ seeding 2 clubs, players, referees, rounds, boxes, user_box_scores, courts
# if true
#   # if Rails.env.development?
#     puts "-------------------"
#     puts "reseting Database"
#     puts "-------------------"
#     Club.destroy_all
#     Round.destroy_all
#     Court.destroy_all
#     Match.destroy_all
#     Box.destroy_all
#     UserBoxScore.destroy_all
#     UserMatchScore.destroy_all
#     User.destroy_all
#   # end

#   puts "-------------------"
#   puts "seeding Clubs"
#   puts "-------------------"
#   sample_club = Club.create(
#     name: "your tennis club"
#   )

#   Club.create(
#     name: "Wimbledon Ltc Club"
#   )
#   Club.create(
#     name: "Holland Park Ltc Club"
#   )

#   User.create(
#     email: "guillaume.cazals@club.be",
#     first_name: "Guillaume",
#     last_name: "Cazals",
#     nickname: "GuillaumeC",
#     phone_number: "+32470970853",
#     password: "650702",
#     role: "admin",
#     club_id: sample_club.id # user needs to belong to a club
#   )

#   clubs = Club.all.reject { |club| club == sample_club }

#   clubs.each do |club|
#     puts "seeding current round for #{club.name}"
#     puts "------------------------------------"
#     round = Round.create(
#       start_date: Date.new(2023, 4, 1),
#       end_date: Date.new(2023, 6, 30),
#       club_id: club.id
#     )
#     puts "-> round created"

#     puts "seeding a Referee for #{club.name}"
#     puts "------------------------------------"
#     first_name = Faker::Name.male_first_name
#     last_name = Faker::Name.last_name
#     nickname = first_name + last_name[0]
#     user = User.create(
#       first_name: first_name,
#       last_name: last_name,
#       nickname: nickname,
#       email: "#{first_name.downcase}.#{last_name.downcase}@club.be",
#       phone_number: Faker::PhoneNumber.cell_phone,
#       password: "654321",
#       club_id: club.id,
#       role: "referee"
#     )

#     puts "-> Referee created: #{user.email}"

#     14.times do |box_number|
#       puts "seeding box #{box_number + 1} for #{club.name}"
#       puts "------------------------------------"
#       box = Box.create(
#         round_id: round.id,
#         box_number: box_number + 1
#       )

#       puts "seeding 6 players and their User-box-score for box #{box_number + 1}"
#       puts "------------------------------------"

#       6.times do
#         # generate 6 random players in the box
#         first_name = Faker::Name.male_first_name
#         last_name = Faker::Name.last_name
#         nickname = first_name + last_name[0]

#         user = User.create(
#           first_name: first_name,
#           last_name: last_name,
#           nickname: nickname,
#           email: "#{first_name.downcase}.#{last_name.downcase}@club.be",
#           phone_number: Faker::PhoneNumber.cell_phone,
#           password: "123456",
#           club_id: club.id,
#           role: "player"
#         )

#         UserBoxScore.create(
#           user_id: user.id,
#           box_id: box.id,
#           points: 0,
#           rank: 0,
#           sets_won: 0,
#           sets_played: 0,
#           games_won: 0,
#           games_played: 0
#         )
#         puts "  -> player and UserBoxScore created: #{user.email}"
#       end
#     end

#     puts "seeding 10 courts for #{club.name}"
#     puts "------------------------------------"
#     10.times do |court_number|
#       Court.create(
#         name: court_number + 1,
#         club_id: club.id
#       )
#     end
#     puts "  -> 10 courts created"
#   end
# end

# new_round = true

# if new_round
#   sample_club = Club.find_by(name: "your tennis club")
#   clubs = Club.all.reject { |club| club == sample_club }

#   clubs.each do |club|
#     puts "seeding current round for #{club.name}"
#     puts "------------------------------------"
#     round = Round.create(
#       start_date: Date.new(2023, 1, 1),
#       end_date: Date.new(2023, 3, 31),
#       club_id: club.id
#     )
#     puts "-> new round created"

#     sourcing_round = Round.find_by(
#       start_date: Date.new(2023, 4, 1),
#       club_id: club.id
#     )
#     sourcing_boxes = Box.where(round_id: sourcing_round.id)

#     14.times do |box_number|
#       puts "seeding box #{box_number + 1} for #{club.name}"
#       puts "------------------------------------"
#       box = Box.create(
#         round_id: round.id,
#         box_number: box_number + 1
#       )

#       matching_box = Box.find_by(
#         round_id: sourcing_round.id,
#         box_number: box.box_number
#       )

#       puts "UserBoxScores for box #{box_number + 1}"
#       puts "------------------------------------"

#       matching_box.user_box_scores.each do |ubs|
#         new_ubs = UserBoxScore.create(
#           user_id: ubs.user_id,
#           box_id: box.id,
#           points: 0,
#           rank: 0,
#           sets_won: 0,
#           sets_played: 0,
#           games_won: 0,
#           games_played: 0
#         )
#         puts "  -> UserBoxScore created for #{new_ubs.user.email}"
#       end
#     end
#   end
# end





# 2/ populate columns games_won and games_played in UserBoxScore records (empty from new migration 29/1/2024)
# UserBoxScore.update_all(games_won: 0, games_played: 0)

# Match.all.each do |match|
#   user_match_scores = match.user_match_scores
#   ums = user_match_scores[0] # player
#   oms = user_match_scores[1] # opponent
#   ubs = UserBoxScore.find_by(user_id: ums.user.id, box_id: ums.match.box.id)
#   puts "UMS id #{ums.id}, #{ums.score_set1}  #{ums.score_set2}  #{ums.score_tiebreak}"
#   puts "OMS id #{oms.id}, #{oms.score_set1}  #{oms.score_set2}  #{oms.score_tiebreak}"
#   ubs.games_won += ums.score_set1 + ums.score_set2 + ums.score_tiebreak
#   ubs.games_played += ums.score_set1 + ums.score_set2 + ums.score_tiebreak +
#                       oms.score_set1 + oms.score_set2 + oms.score_tiebreak
#   puts "  > UBS id: #{ubs.id}, games won    #{ubs.games_won}"
#   puts "  > UBS id: #{ubs.id}, games played #{ubs.games_played}"
#   puts ""
#   puts ubs.save

#   obs = UserBoxScore.find_by(user_id: oms.user.id, box_id: oms.match.box.id)
#   obs.games_won += oms.score_set1 + oms.score_set2 + oms.score_tiebreak
#   obs.games_played += ums.score_set1 + ums.score_set2 + ums.score_tiebreak +
#                       oms.score_set1 + oms.score_set2 + oms.score_tiebreak
#   puts "  > OBS id: #{obs.id}, games won    #{obs.games_won}"
#   puts "  > OBS id: #{obs.id}, games played #{obs.games_played}"
#   puts obs.save
#   puts "------------------------------------"
# end

# 3/ rename chatrooms from eg: "Wimbledon Ltc Club - B04/R23_03" to "Wimbledon Ltc Club - R23_03:B04"
# general = Chatroom.find_by(name: "general")
# chatrooms = Chatroom.excluding(general)

# chatrooms.each do |chatroom|
#   puts "Chatroom id: #{chatroom.id}, old name: #{chatroom.name}"
#   roundname = chatroom.name[-6, 6]
#   boxname = chatroom.name[-10, 3]
#   newname = "#{chatroom.name[0, chatroom.name.size - 10]}#{roundname}:#{boxname}"
#   chatroom.update(name: newname)
#   puts ">> new name: #{chatroom.name}"
# end

# 4/ Following migration 20240208214333_add_league_start_to_rounds, populate field league_start with the
# start_date of the first round of the year; going forward, this field allows creating tournaments starting
# any time in the year
# sample_club = Club.find_by(name: "your tennis club")
# clubs = Club.all.reject { |club| club == sample_club }
# clubs.each do |club|
#   puts "Club: #{club.name}"
#   start_dates = club.rounds.map(&:start_date).sort.reverse
#   start_dates = start_dates.map { |round_start_date| round_start_date.strftime('%d/%m/%Y') }
#   round_years = start_dates.map { |round_start_date| round_start_date.to_date.year }.uniq
#   round_years.each do |round_year|
#     rounds_ordered = Round.where('extract(year  from start_date) = ?', round_year)
#     .where(club_id: club)
#     .order('start_date ASC')
#     .map(&:id)
#     rounds_ordered.each do |round_id|
#       round = Round.find(round_id)
#       puts "Round: #{round_id}: #{round.start_date}"
#       league_start = Date.new(round.start_date.year, 1, 1)
#       round.update(league_start:)
#       puts ">>>>>: #{round.league_start}"
#     end
#   end
# end

# 5/ destroy matches and user_match_scores for a club
# Court.where(club_id: 65).each{ |court| court.matches.each {|match| match.destroy }}
# or:
# Box.where(round_id: 22).each do |box|
#   box.matches.each do |match|
#     match.destroy
#   end
# end
# 6/ clean user box scores
# # User.where(club_id:65).each{|user| user.user_box_scores.each{|ubs| ubs.update(points: 0, rank: 1,
                                    #  sets_won: 0, sets_played: 0,
                                    #  matches_won: 0, matches_played: 0,
                                    #  games_won: 0, games_played: 0)}}
# or:
# Box.where(round_id:180).each{|box| box.user_box_scores.each{|ubs| ubs.update(points: 0, rank: 1,
                                        # sets_won: 0, sets_played: 0,
                                        # matches_won: 0, matches_played: 0,
                                        # games_won: 0, games_played: 0)}}


# def destroy(match)
#   # for admin and referees only
#   # @match = Match.find(params[:id])
#   user_match_scores = UserMatchScore.where(match_id: match.id)
#   results = compute_results(user_match_scores)
#   # update user_box_score for each player
#   [0, 1].each do |index|
#     user_box_score = UserBoxScore.find_by(box_id: match.box_id, user_id: user_match_scores[index].user_id)

#     user_box_score.points -= user_match_scores[index].points
#     user_box_score.sets_won -= results[index]
#     user_box_score.sets_played -= results.sum
#     user_box_score.games_won -= won_games(user_match_scores[index])
#     user_box_score.games_played -= won_games(user_match_scores[index]) + won_games(user_match_scores[1 - index])
#     user_box_score.matches_won -= results[index] > results[1 - index] ? 1 : 0
#     user_box_score.matches_played -= 1
#     user_box_score.save
#   end
#   match.destroy

#   # update the league table
#   rank_players(match.box.round.user_box_scores)
# end


# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2023_10_18_223106) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "boxes", force: :cascade do |t|
    t.integer "box_number"
    t.bigint "round_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "chatroom_id", null: false
    t.index ["chatroom_id"], name: "index_boxes_on_chatroom_id"
    t.index ["round_id"], name: "index_boxes_on_round_id"
  end

  create_table "chatrooms", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "clubs", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "courts", force: :cascade do |t|
    t.string "name"
    t.bigint "club_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id"], name: "index_courts_on_club_id"
  end

  create_table "matches", force: :cascade do |t|
    t.datetime "time"
    t.bigint "court_id", null: false
    t.bigint "box_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["box_id"], name: "index_matches_on_box_id"
    t.index ["court_id"], name: "index_matches_on_court_id"
  end

  create_table "messages", force: :cascade do |t|
    t.string "content"
    t.bigint "chatroom_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chatroom_id"], name: "index_messages_on_chatroom_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "rounds", force: :cascade do |t|
    t.date "start_date"
    t.date "end_date"
    t.bigint "club_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id"], name: "index_rounds_on_club_id"
  end

  create_table "user_box_scores", force: :cascade do |t|
    t.integer "points"
    t.integer "rank"
    t.bigint "user_id", null: false
    t.bigint "box_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "sets_won"
    t.integer "sets_played"
    t.integer "games_won"
    t.integer "games_played"
    t.index ["box_id"], name: "index_user_box_scores_on_box_id"
    t.index ["user_id"], name: "index_user_box_scores_on_user_id"
  end

  create_table "user_match_scores", force: :cascade do |t|
    t.integer "points"
    t.integer "score_set1"
    t.integer "score_set2"
    t.integer "score_tiebreak"
    t.boolean "is_winner"
    t.bigint "user_id", null: false
    t.bigint "match_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "input_user_id"
    t.datetime "input_date"
    t.index ["match_id"], name: "index_user_match_scores_on_match_id"
    t.index ["user_id"], name: "index_user_match_scores_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "nickname"
    t.string "phone_number"
    t.bigint "club_id", null: false
    t.string "role"
    t.index ["club_id"], name: "index_users_on_club_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "boxes", "chatrooms"
  add_foreign_key "boxes", "rounds"
  add_foreign_key "courts", "clubs"
  add_foreign_key "matches", "boxes"
  add_foreign_key "matches", "courts"
  add_foreign_key "messages", "chatrooms"
  add_foreign_key "messages", "users"
  add_foreign_key "rounds", "clubs"
  add_foreign_key "user_box_scores", "boxes"
  add_foreign_key "user_box_scores", "users"
  add_foreign_key "user_match_scores", "matches"
  add_foreign_key "user_match_scores", "users"
  add_foreign_key "users", "clubs"
end

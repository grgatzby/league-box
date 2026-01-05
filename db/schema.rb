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

ActiveRecord::Schema[7.0].define(version: 2026_01_05_013350) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "boxes", force: :cascade do |t|
    t.integer "box_number"
    t.bigint "round_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "chatroom_id", null: false
    t.index ["chatroom_id"], name: "index_boxes_on_chatroom_id"
    t.index ["round_id"], name: "index_boxes_on_round_id"
  end

  create_table "chatroom_reads", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "chatroom_id", null: false
    t.datetime "last_read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chatroom_id"], name: "index_chatroom_reads_on_chatroom_id"
    t.index ["user_id", "chatroom_id"], name: "index_chatroom_reads_on_user_id_and_chatroom_id", unique: true
    t.index ["user_id"], name: "index_chatroom_reads_on_user_id"
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

  create_table "gallery_images", force: :cascade do |t|
    t.string "image"
    t.text "caption"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "club_id", null: false
    t.integer "accessible_club_ids", default: [], array: true
    t.index ["accessible_club_ids"], name: "index_gallery_images_on_accessible_club_ids", using: :gin
    t.index ["club_id"], name: "index_gallery_images_on_club_id"
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

  create_table "preferences", force: :cascade do |t|
    t.boolean "clear_format"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_preferences_on_user_id"
  end

  create_table "rounds", force: :cascade do |t|
    t.date "start_date"
    t.date "end_date"
    t.bigint "club_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "league_start"
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
    t.integer "matches_won"
    t.integer "matches_played"
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
    t.string "profile_picture"
    t.index ["club_id"], name: "index_users_on_club_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "boxes", "chatrooms"
  add_foreign_key "boxes", "rounds"
  add_foreign_key "chatroom_reads", "chatrooms"
  add_foreign_key "chatroom_reads", "users"
  add_foreign_key "courts", "clubs"
  add_foreign_key "gallery_images", "clubs"
  add_foreign_key "matches", "boxes"
  add_foreign_key "matches", "courts"
  add_foreign_key "messages", "chatrooms"
  add_foreign_key "messages", "users"
  add_foreign_key "preferences", "users"
  add_foreign_key "rounds", "clubs"
  add_foreign_key "user_box_scores", "boxes"
  add_foreign_key "user_box_scores", "users"
  add_foreign_key "user_match_scores", "matches"
  add_foreign_key "user_match_scores", "users"
  add_foreign_key "users", "clubs"
end

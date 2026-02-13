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

ActiveRecord::Schema[8.1].define(version: 2026_02_13_010610) do
  create_schema "scoreboard"

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "scoreboard.groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.string "invitation_token", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_groups_on_created_by_id"
    t.index ["invitation_token"], name: "index_groups_on_invitation_token", unique: true
  end

  create_table "scoreboard.memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "group_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["group_id"], name: "index_memberships_on_group_id"
    t.index ["user_id", "group_id"], name: "index_memberships_on_user_id_and_group_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "scoreboard.players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name", null: false
    t.bigint "group_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["group_id", "user_id"], name: "index_players_on_group_id_and_user_id", unique: true, where: "(user_id IS NOT NULL)"
    t.index ["group_id"], name: "index_players_on_group_id"
    t.index ["user_id"], name: "index_players_on_user_id"
  end

  create_table "scoreboard.poker_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.bigint "group_id", null: false
    t.text "note"
    t.date "played_on", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_poker_sessions_on_created_by_id"
    t.index ["group_id", "played_on"], name: "index_poker_sessions_on_group_id_and_played_on"
    t.index ["group_id"], name: "index_poker_sessions_on_group_id"
  end

  create_table "scoreboard.session_results", force: :cascade do |t|
    t.integer "amount", null: false
    t.datetime "created_at", null: false
    t.bigint "player_id", null: false
    t.bigint "poker_session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_session_results_on_player_id"
    t.index ["poker_session_id", "player_id"], name: "index_session_results_on_poker_session_id_and_player_id", unique: true
    t.index ["poker_session_id"], name: "index_session_results_on_poker_session_id"
  end

  create_table "scoreboard.users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "display_name", default: "", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "provider", default: "google_oauth2", null: false
    t.datetime "remember_created_at"
    t.string "uid", default: "", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  add_foreign_key "scoreboard.groups", "scoreboard.users", column: "created_by_id"
  add_foreign_key "scoreboard.memberships", "scoreboard.groups"
  add_foreign_key "scoreboard.memberships", "scoreboard.users"
  add_foreign_key "scoreboard.players", "scoreboard.groups"
  add_foreign_key "scoreboard.players", "scoreboard.users"
  add_foreign_key "scoreboard.poker_sessions", "scoreboard.groups"
  add_foreign_key "scoreboard.poker_sessions", "scoreboard.users", column: "created_by_id"
  add_foreign_key "scoreboard.session_results", "scoreboard.players"
  add_foreign_key "scoreboard.session_results", "scoreboard.poker_sessions"

end

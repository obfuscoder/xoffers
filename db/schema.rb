# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170818185720) do

  create_table "channels", force: :cascade do |t|
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
    t.integer  "network_id", limit: 4
    t.string   "name",       limit: 64, null: false
  end

  add_index "channels", ["network_id", "name"], name: "index_channels_on_network_id_and_name", unique: true, using: :btree

  create_table "downloads", force: :cascade do |t|
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.string   "name",       limit: 255
    t.string   "status",     limit: 255
    t.integer  "size",       limit: 8
    t.integer  "position",   limit: 8
    t.string   "ip",         limit: 255
    t.integer  "port",       limit: 4
    t.integer  "user_id",    limit: 4
  end

  create_table "networks", force: :cascade do |t|
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
    t.string   "name",       limit: 32, null: false
  end

  add_index "networks", ["name"], name: "index_networks_on_name", unique: true, using: :btree

  create_table "packs", force: :cascade do |t|
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.integer  "user_id",        limit: 4
    t.integer  "number",         limit: 4,   null: false
    t.string   "name",           limit: 255
    t.integer  "download_count", limit: 4
    t.string   "size",           limit: 255
  end

  add_index "packs", ["user_id", "number"], name: "index_packs_on_user_id_and_number", unique: true, using: :btree

  create_table "servers", force: :cascade do |t|
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.integer  "network_id", limit: 4
    t.string   "address",    limit: 128, null: false
    t.integer  "port",       limit: 4
  end

  add_index "servers", ["address"], name: "index_servers_on_address", unique: true, using: :btree
  add_index "servers", ["network_id"], name: "fk_rails_f80f6dfcbe", using: :btree

  create_table "users", force: :cascade do |t|
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
    t.integer  "network_id",       limit: 4
    t.string   "name",             limit: 128, null: false
    t.boolean  "online"
    t.integer  "pack_count",       limit: 4
    t.integer  "open_slot_count",  limit: 4
    t.integer  "total_slot_count", limit: 4
    t.integer  "queue_size",       limit: 4
    t.integer  "queued_count",     limit: 4
    t.string   "min_speed",        limit: 255
    t.string   "max_speed",        limit: 255
    t.string   "current_speed",    limit: 255
    t.string   "offered_size",     limit: 255
    t.string   "transferred_size", limit: 255
    t.boolean  "passive"
  end

  add_index "users", ["network_id", "name"], name: "index_users_on_network_id_and_name", unique: true, using: :btree

  add_foreign_key "channels", "networks"
  add_foreign_key "packs", "users"
  add_foreign_key "servers", "networks"
  add_foreign_key "users", "networks"
end

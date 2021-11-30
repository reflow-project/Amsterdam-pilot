# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_11_19_094027) do

  create_table "agents", force: :cascade do |t|
    t.string "label"
    t.integer "agent_type"
    t.integer "telegram_id"
    t.string "ros_id"
    t.string "dialog_state"
    t.integer "dialog_subject"
    t.string "role"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "events", force: :cascade do |t|
    t.integer "event_type"
    t.integer "source_agent_id"
    t.integer "target_agent_id"
    t.integer "resource_id"
    t.string "location"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "resources", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "image_url"
    t.string "tracking_id"
    t.integer "shop_id"
    t.string "ros_id"
    t.integer "owner"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "stories", force: :cascade do |t|
    t.integer "resource_id"
    t.text "content"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "transcripts", force: :cascade do |t|
    t.integer "resource_id"
    t.integer "agent_id"
    t.string "dialog_key"
    t.text "dialog_value"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

end

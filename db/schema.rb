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

ActiveRecord::Schema[7.2].define(version: 2025_08_20_092251) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "users", force: :cascade do |t|
    t.string "email1"
    t.string "email2"
    t.string "name1"
    t.string "name2"
    t.boolean "sex1"
    t.boolean "sex2"
    t.integer "age1"
    t.integer "age2"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["age1"], name: "index_users_on_age1"
    t.index ["email1"], name: "index_users_on_email1"
    t.index ["name1"], name: "index_users_on_name1"
    t.index ["sex1"], name: "index_users_on_sex1"
  end
end

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

ActiveRecord::Schema.define(version: 20140730194339) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "postgis"

  create_table "cai_category", force: true do |t|
    t.integer  "code",                      null: false
    t.string   "name"
    t.integer  "position",   default: 0,    null: false
    t.boolean  "display",    default: true, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "cai_category", ["code"], :name => "index_cai_category_on_code", :unique => true

  create_table "county", force: true do |t|
    t.integer  "gid",                                              null: false
    t.string   "name",                                             null: false
    t.string   "geoid",                                            null: false
    t.integer  "state_id",                                         null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.spatial  "geometry",   limit: {:srid=>0, :type=>"geometry"}
  end

  add_index "county", ["geoid"], :name => "index_county_on_geoid", :unique => true
  add_index "county", ["geometry"], :name => "index_county_on_geometry", :spatial => true
  add_index "county", ["gid"], :name => "index_county_on_gid", :unique => true
  add_index "county", ["name"], :name => "index_county_on_name"

  create_table "district", force: true do |t|
    t.integer  "gid",                                                  null: false
    t.string   "name",                                                 null: false
    t.string   "geoid",                                                null: false
    t.integer  "state_id",                                             null: false
    t.string   "representative"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.spatial  "geometry",       limit: {:srid=>0, :type=>"geometry"}
  end

  add_index "district", ["geoid"], :name => "index_district_on_geoid", :unique => true
  add_index "district", ["geometry"], :name => "index_district_on_geometry", :spatial => true
  add_index "district", ["gid"], :name => "index_district_on_gid", :unique => true
  add_index "district", ["name"], :name => "index_district_on_name"
  add_index "district", ["state_id"], :name => "index_district_on_state_id"

  create_table "institution", force: true do |t|
    t.integer  "cai_category_id"
    t.string   "name",                                                  null: false
    t.string   "address"
    t.string   "url"
    t.string   "caiid"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.spatial  "geometry",        limit: {:srid=>0, :type=>"geometry"}
  end

  add_index "institution", ["cai_category_id"], :name => "index_institution_on_cai_category_id"
  add_index "institution", ["geometry"], :name => "index_institution_on_geometry", :spatial => true
  add_index "institution", ["name"], :name => "index_institution_on_name"

  create_table "map", force: true do |t|
    t.string   "name",                                                           null: false
    t.integer  "state_id"
    t.text     "disclaimer"
    t.integer  "initial_zoom",                                       default: 7, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.spatial  "geometry",     limit: {:srid=>0, :type=>"geometry"}
    t.spatial  "centroid",     limit: {:srid=>0, :type=>"point"}
  end

  add_index "map", ["geometry"], :name => "index_map_on_geometry", :spatial => true

  create_table "map_style", force: true do |t|
    t.integer  "map_id",         null: false
    t.integer  "layerable_id"
    t.string   "layerable_type"
    t.string   "name"
    t.string   "color"
    t.string   "graphic_name"
    t.decimal  "opacity"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "map_style", ["map_id"], :name => "index_map_style_on_map_id"

  create_table "provider", force: true do |t|
    t.string   "name",       null: false
    t.string   "name_dba"
    t.string   "name_short"
    t.string   "website"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "provider", ["name", "name_dba"], :name => "index_provider_on_name_and_name_dba"

  create_table "provider_frn", force: true do |t|
    t.integer  "provider_id", null: false
    t.string   "frn",         null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "provider_frn", ["provider_id"], :name => "index_provider_frn_on_provider_id"

  create_table "provider_service", force: true do |t|
    t.integer  "provider_id",                                                        null: false
    t.integer  "technology_id",                                                      null: false
    t.integer  "speed_up_id",                                                        null: false
    t.integer  "speed_down_id",                                                      null: false
    t.boolean  "commercial",                                          default: true, null: false
    t.boolean  "residential",                                         default: true, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.spatial  "geometry",      limit: {:srid=>0, :type=>"geometry"}
  end

  add_index "provider_service", ["geometry"], :name => "index_provider_service_on_geometry", :spatial => true
  add_index "provider_service", ["provider_id", "technology_id"], :name => "index_provider_service_on_provider_id_and_technology_id"

  create_table "served_area", force: true do |t|
    t.integer  "technology_id",                                                      null: false
    t.boolean  "commercial",                                          default: true, null: false
    t.boolean  "residential",                                         default: true, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.spatial  "geometry",      limit: {:srid=>0, :type=>"geometry"}
  end

  add_index "served_area", ["geometry"], :name => "index_served_area_on_geometry", :spatial => true
  add_index "served_area", ["technology_id"], :name => "index_served_area_on_technology_id"

  create_table "speed_tier", force: true do |t|
    t.integer  "code",        null: false
    t.string   "description"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "speed_tier", ["code"], :name => "index_speed_tier_on_code", :unique => true

  create_table "state", force: true do |t|
    t.integer  "gid",                                              null: false
    t.string   "name",                                             null: false
    t.string   "statefp",                                          null: false
    t.string   "geoid",                                            null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.spatial  "geometry",   limit: {:srid=>0, :type=>"geometry"}
  end

  add_index "state", ["geoid"], :name => "index_state_on_geoid", :unique => true
  add_index "state", ["geometry"], :name => "index_state_on_geometry", :spatial => true
  add_index "state", ["gid"], :name => "index_state_on_gid", :unique => true
  add_index "state", ["statefp"], :name => "index_state_on_statefp", :unique => true

  create_table "tech_type", force: true do |t|
    t.integer  "code",          null: false
    t.string   "name"
    t.integer  "technology_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "tech_type", ["code"], :name => "index_tech_type_on_code", :unique => true
  add_index "tech_type", ["technology_id"], :name => "index_tech_type_on_technology_id"

  create_table "technology", force: true do |t|
    t.string   "name",                                              null: false
    t.text     "description"
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.spatial  "geometry",    limit: {:srid=>0, :type=>"geometry"}
  end

  add_index "technology", ["name"], :name => "index_technology_on_name", :unique => true

  create_table "user_profile", force: true do |t|
    t.string   "username",                              null: false
    t.string   "email",                                 null: false
    t.string   "name",                                  null: false
    t.boolean  "active",                 default: true
    t.string   "encrypted_password"
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.integer  "failed_attempts",        default: 0
    t.string   "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "user_profile", ["email"], :name => "index_user_profile_on_email", :unique => true
  add_index "user_profile", ["username"], :name => "index_user_profile_on_username", :unique => true

  create_table "zip_code", force: true do |t|
    t.integer  "gid",                                              null: false
    t.string   "name",                                             null: false
    t.string   "geoid",                                            null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.spatial  "geometry",   limit: {:srid=>0, :type=>"geometry"}
  end

  add_index "zip_code", ["geoid"], :name => "index_zip_code_on_geoid", :unique => true
  add_index "zip_code", ["geometry"], :name => "index_zip_code_on_geometry", :spatial => true
  add_index "zip_code", ["gid"], :name => "index_zip_code_on_gid", :unique => true
  add_index "zip_code", ["name"], :name => "index_zip_code_on_name", :unique => true

end

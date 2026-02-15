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

ActiveRecord::Schema[8.1].define(version: 2026_02_15_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "exam_attempt_items", force: :cascade do |t|
    t.datetime "answered_at"
    t.boolean "answered_correctly"
    t.string "correct_key", limit: 1, null: false
    t.datetime "created_at", null: false
    t.bigint "exam_attempt_id", null: false
    t.integer "points_possible", null: false
    t.integer "position", null: false
    t.bigint "question_id", null: false
    t.string "selected_key", limit: 1
    t.jsonb "snapshot", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["exam_attempt_id", "answered_correctly"], name: "idx_on_exam_attempt_id_answered_correctly_5c1e9507f5"
    t.index ["exam_attempt_id", "position"], name: "index_exam_attempt_items_on_exam_attempt_id_and_position", unique: true
    t.index ["exam_attempt_id", "question_id"], name: "index_exam_attempt_items_on_exam_attempt_id_and_question_id", unique: true
    t.index ["exam_attempt_id"], name: "index_exam_attempt_items_on_exam_attempt_id"
    t.index ["question_id"], name: "index_exam_attempt_items_on_question_id"
    t.check_constraint "\"position\" > 0", name: "exam_attempt_items_position_positive"
    t.check_constraint "correct_key::text = ANY (ARRAY['T'::character varying, 'N'::character varying, 'A'::character varying, 'B'::character varying, 'C'::character varying]::text[])", name: "exam_attempt_items_correct_key_valid"
    t.check_constraint "points_possible = ANY (ARRAY[1, 2, 3])", name: "exam_attempt_items_points_possible_valid"
    t.check_constraint "selected_key IS NULL OR (selected_key::text = ANY (ARRAY['T'::character varying, 'N'::character varying, 'A'::character varying, 'B'::character varying, 'C'::character varying]::text[]))", name: "exam_attempt_items_selected_key_valid"
  end

  create_table "exam_attempts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deadline_at", null: false
    t.bigint "exam_blueprint_id", null: false
    t.bigint "license_category_id"
    t.string "locale", limit: 5, default: "pl", null: false
    t.integer "max_score", default: 74, null: false
    t.boolean "passed"
    t.bigint "question_bank_id", null: false
    t.bigint "random_seed"
    t.integer "score"
    t.datetime "started_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.index ["exam_blueprint_id"], name: "index_exam_attempts_on_exam_blueprint_id"
    t.index ["license_category_id"], name: "index_exam_attempts_on_license_category_id"
    t.index ["question_bank_id"], name: "index_exam_attempts_on_question_bank_id"
    t.index ["started_at"], name: "index_exam_attempts_on_started_at"
    t.index ["status"], name: "index_exam_attempts_on_status"
    t.index ["uuid"], name: "index_exam_attempts_on_uuid", unique: true
    t.check_constraint "deadline_at >= started_at", name: "exam_attempts_deadline_after_start"
    t.check_constraint "locale::text = ANY (ARRAY['pl'::character varying, 'en'::character varying, 'de'::character varying, 'ua'::character varying]::text[])", name: "exam_attempts_locale_valid"
    t.check_constraint "max_score > 0", name: "exam_attempts_max_score_positive"
    t.check_constraint "score IS NULL OR score >= 0 AND score <= max_score", name: "exam_attempts_score_valid_range"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2, 3])", name: "exam_attempts_status_valid"
  end

  create_table "exam_blueprint_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "exam_blueprint_id", null: false
    t.integer "question_weight", null: false
    t.integer "questions_count", null: false
    t.integer "scope", null: false
    t.datetime "updated_at", null: false
    t.index ["exam_blueprint_id", "scope", "question_weight"], name: "idx_on_exam_blueprint_id_scope_question_weight_5cb3bb80de", unique: true
    t.index ["exam_blueprint_id"], name: "index_exam_blueprint_rules_on_exam_blueprint_id"
    t.check_constraint "question_weight = ANY (ARRAY[1, 2, 3])", name: "exam_blueprint_rules_weight_valid"
    t.check_constraint "questions_count > 0", name: "exam_blueprint_rules_questions_count_positive"
    t.check_constraint "scope = ANY (ARRAY[0, 1])", name: "exam_blueprint_rules_scope_valid"
  end

  create_table "exam_blueprints", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "basic_questions_count", default: 20, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "duration_minutes", default: 25, null: false
    t.date "effective_from"
    t.date "effective_to"
    t.integer "max_score", default: 74, null: false
    t.string "name", null: false
    t.integer "pass_score", default: 68, null: false
    t.integer "questions_total", default: 32, null: false
    t.integer "specialist_questions_count", default: 12, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_exam_blueprints_on_name", unique: true
    t.check_constraint "basic_questions_count > 0", name: "exam_blueprints_basic_count_positive"
    t.check_constraint "duration_minutes > 0", name: "exam_blueprints_duration_positive"
    t.check_constraint "effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from", name: "exam_blueprints_effective_dates_order"
    t.check_constraint "max_score > 0", name: "exam_blueprints_max_score_positive"
    t.check_constraint "pass_score <= max_score", name: "exam_blueprints_pass_not_above_max"
    t.check_constraint "pass_score > 0", name: "exam_blueprints_pass_score_positive"
    t.check_constraint "questions_total = (basic_questions_count + specialist_questions_count)", name: "exam_blueprints_total_matches_parts"
    t.check_constraint "questions_total > 0", name: "exam_blueprints_questions_total_positive"
    t.check_constraint "specialist_questions_count > 0", name: "exam_blueprints_specialist_count_positive"
  end

  create_table "import_issues", force: :cascade do |t|
    t.string "code", null: false
    t.jsonb "context", default: {}, null: false
    t.datetime "created_at", null: false
    t.bigint "import_run_id", null: false
    t.text "message", null: false
    t.integer "row_number"
    t.integer "severity", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_import_issues_on_code"
    t.index ["import_run_id", "severity"], name: "index_import_issues_on_import_run_id_and_severity"
    t.index ["import_run_id"], name: "index_import_issues_on_import_run_id"
    t.check_constraint "row_number IS NULL OR row_number > 0", name: "import_issues_row_number_positive"
    t.check_constraint "severity = ANY (ARRAY[0, 1])", name: "import_issues_severity_valid"
  end

  create_table "import_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "error_count", default: 0, null: false
    t.datetime "finished_at"
    t.integer "imported_rows", default: 0, null: false
    t.bigint "question_bank_id"
    t.integer "skipped_rows", default: 0, null: false
    t.string "source_checksum"
    t.string "source_filename", null: false
    t.datetime "started_at", null: false
    t.integer "status", default: 0, null: false
    t.text "summary"
    t.integer "total_rows", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "warning_count", default: 0, null: false
    t.index ["question_bank_id"], name: "index_import_runs_on_question_bank_id"
    t.index ["started_at"], name: "index_import_runs_on_started_at"
    t.index ["status"], name: "index_import_runs_on_status"
    t.check_constraint "error_count >= 0", name: "import_runs_error_count_non_negative"
    t.check_constraint "finished_at IS NULL OR finished_at >= started_at", name: "import_runs_finished_after_start"
    t.check_constraint "imported_rows >= 0", name: "import_runs_imported_rows_non_negative"
    t.check_constraint "skipped_rows >= 0", name: "import_runs_skipped_rows_non_negative"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2, 3])", name: "import_runs_status_valid"
    t.check_constraint "total_rows >= 0", name: "import_runs_total_rows_non_negative"
    t.check_constraint "warning_count >= 0", name: "import_runs_warning_count_non_negative"
  end

  create_table "license_categories", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_license_categories_on_code", unique: true
  end

  create_table "media_assets", force: :cascade do |t|
    t.bigint "byte_size"
    t.string "checksum_sha256"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.integer "height"
    t.integer "kind", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "normalized_filename"
    t.integer "processing_status", default: 0, null: false
    t.string "source_filename", null: false
    t.datetime "updated_at", null: false
    t.integer "width"
    t.index ["checksum_sha256"], name: "index_media_assets_on_checksum_sha256"
    t.index ["normalized_filename"], name: "index_media_assets_on_normalized_filename"
    t.index ["source_filename"], name: "index_media_assets_on_source_filename"
    t.check_constraint "byte_size IS NULL OR byte_size >= 0", name: "media_assets_byte_size_non_negative"
    t.check_constraint "duration_ms IS NULL OR duration_ms >= 0", name: "media_assets_duration_non_negative"
    t.check_constraint "height IS NULL OR height > 0", name: "media_assets_height_positive"
    t.check_constraint "kind = ANY (ARRAY[0, 1])", name: "media_assets_kind_valid"
    t.check_constraint "processing_status = ANY (ARRAY[0, 1, 2, 3])", name: "media_assets_processing_status_valid"
    t.check_constraint "width IS NULL OR width > 0", name: "media_assets_width_positive"
  end

  create_table "question_banks", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.string "identifier", null: false
    t.datetime "imported_at"
    t.text "notes"
    t.date "published_on"
    t.string "source_checksum"
    t.string "source_filename"
    t.datetime "updated_at", null: false
    t.index ["identifier"], name: "index_question_banks_on_identifier", unique: true
  end

  create_table "question_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "license_category_id", null: false
    t.bigint "question_id", null: false
    t.datetime "updated_at", null: false
    t.index ["license_category_id"], name: "index_question_categories_on_license_category_id"
    t.index ["question_id", "license_category_id"], name: "idx_on_question_id_license_category_id_b4f31742ff", unique: true
    t.index ["question_id"], name: "index_question_categories_on_question_id"
  end

  create_table "question_media_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "media_asset_id"
    t.bigint "question_id", null: false
    t.integer "slot", null: false
    t.string "source_filename", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["media_asset_id", "slot"], name: "index_question_media_links_on_media_asset_id_and_slot"
    t.index ["media_asset_id"], name: "index_question_media_links_on_media_asset_id"
    t.index ["question_id", "slot"], name: "index_question_media_links_on_question_id_and_slot", unique: true
    t.index ["question_id"], name: "index_question_media_links_on_question_id"
    t.index ["source_filename"], name: "index_question_media_links_on_source_filename"
    t.check_constraint "slot = ANY (ARRAY[0, 1, 2, 3, 4])", name: "question_media_links_slot_valid"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2])", name: "question_media_links_status_valid"
  end

  create_table "question_option_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "locale", limit: 5, null: false
    t.bigint "question_option_id", null: false
    t.text "text", null: false
    t.datetime "updated_at", null: false
    t.index ["question_option_id", "locale"], name: "idx_on_question_option_id_locale_e9104a9ff3", unique: true
    t.index ["question_option_id"], name: "index_question_option_translations_on_question_option_id"
    t.check_constraint "locale::text = ANY (ARRAY['pl'::character varying, 'en'::character varying, 'de'::character varying, 'ua'::character varying]::text[])", name: "question_option_translations_locale_valid"
  end

  create_table "question_options", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", limit: 1, null: false
    t.integer "position", null: false
    t.bigint "question_id", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id", "key"], name: "index_question_options_on_question_id_and_key", unique: true
    t.index ["question_id", "position"], name: "index_question_options_on_question_id_and_position", unique: true
    t.index ["question_id"], name: "index_question_options_on_question_id"
    t.check_constraint "\"position\" >= 1 AND \"position\" <= 3", name: "question_options_position_valid"
    t.check_constraint "key::text = ANY (ARRAY['A'::character varying, 'B'::character varying, 'C'::character varying]::text[])", name: "question_options_key_valid"
  end

  create_table "question_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "locale", limit: 5, null: false
    t.bigint "question_id", null: false
    t.text "stem", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id", "locale"], name: "index_question_translations_on_question_id_and_locale", unique: true
    t.index ["question_id"], name: "index_question_translations_on_question_id"
    t.check_constraint "locale::text = ANY (ARRAY['pl'::character varying, 'en'::character varying, 'de'::character varying, 'ua'::character varying]::text[])", name: "question_translations_locale_valid"
  end

  create_table "questions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "answer_mode", null: false
    t.string "correct_key", limit: 1, null: false
    t.datetime "created_at", null: false
    t.integer "official_number", null: false
    t.bigint "question_bank_id", null: false
    t.integer "question_weight"
    t.integer "scope", null: false
    t.integer "source_lp"
    t.integer "source_row"
    t.datetime "updated_at", null: false
    t.index ["question_bank_id", "official_number"], name: "index_questions_on_question_bank_id_and_official_number", unique: true
    t.index ["question_bank_id"], name: "index_questions_on_question_bank_id"
    t.index ["scope", "question_weight", "active"], name: "index_questions_on_scope_and_question_weight_and_active"
    t.index ["source_row"], name: "index_questions_on_source_row"
    t.check_constraint "answer_mode = 0 AND (correct_key::text = ANY (ARRAY['T'::character varying, 'N'::character varying]::text[])) OR answer_mode = 1 AND (correct_key::text = ANY (ARRAY['A'::character varying, 'B'::character varying, 'C'::character varying]::text[]))", name: "questions_correct_key_matches_mode"
    t.check_constraint "answer_mode = ANY (ARRAY[0, 1])", name: "questions_answer_mode_valid"
    t.check_constraint "correct_key::text = ANY (ARRAY['T'::character varying, 'N'::character varying, 'A'::character varying, 'B'::character varying, 'C'::character varying]::text[])", name: "questions_correct_key_valid"
    t.check_constraint "question_weight IS NULL OR (question_weight = ANY (ARRAY[1, 2, 3]))", name: "questions_weight_valid"
    t.check_constraint "scope = ANY (ARRAY[0, 1])", name: "questions_scope_valid"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "exam_attempt_items", "exam_attempts"
  add_foreign_key "exam_attempt_items", "questions"
  add_foreign_key "exam_attempts", "exam_blueprints"
  add_foreign_key "exam_attempts", "license_categories"
  add_foreign_key "exam_attempts", "question_banks"
  add_foreign_key "exam_blueprint_rules", "exam_blueprints"
  add_foreign_key "import_issues", "import_runs"
  add_foreign_key "import_runs", "question_banks"
  add_foreign_key "question_categories", "license_categories"
  add_foreign_key "question_categories", "questions"
  add_foreign_key "question_media_links", "media_assets"
  add_foreign_key "question_media_links", "questions"
  add_foreign_key "question_option_translations", "question_options"
  add_foreign_key "question_options", "questions"
  add_foreign_key "question_translations", "questions"
  add_foreign_key "questions", "question_banks"
end

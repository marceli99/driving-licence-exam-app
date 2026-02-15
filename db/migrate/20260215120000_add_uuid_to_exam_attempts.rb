class AddUuidToExamAttempts < ActiveRecord::Migration[8.1]
  def up
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    add_column :exam_attempts, :uuid, :uuid
    add_index :exam_attempts, :uuid, unique: true

    execute <<~SQL.squish
      UPDATE exam_attempts
      SET uuid = gen_random_uuid()
      WHERE uuid IS NULL
    SQL

    change_column_null :exam_attempts, :uuid, false
    change_column_default :exam_attempts, :uuid, -> { "gen_random_uuid()" }
  end

  def down
    remove_index :exam_attempts, :uuid
    remove_column :exam_attempts, :uuid
  end
end

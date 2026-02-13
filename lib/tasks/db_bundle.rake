require "fileutils"
require "json"
require "shellwords"

module DbBundleTasks
  module_function

  def db_config_hash
    ActiveRecord::Base.connection_db_config.configuration_hash.symbolize_keys
  end

  def ensure_postgresql!(config)
    adapter = config.fetch(:adapter, "").to_s
    return if adapter == "postgresql"

    raise "db:bundle tasks support only PostgreSQL (current adapter: #{adapter.inspect})"
  end

  def pg_password_env(config)
    password = config[:password].presence
    return {} if password.blank?

    { "PGPASSWORD" => password.to_s }
  end

  def pg_connection_args(config)
    args = []
    args << "--dbname=#{config.fetch(:database)}"
    args << "--host=#{config[:host]}" if config[:host].present?
    args << "--port=#{config[:port]}" if config[:port].present?
    args << "--username=#{config[:username]}" if config[:username].present?
    args
  end

  def pg_tool(tool, env_key:)
    override = ENV[env_key].presence
    return override if override.present?

    candidates = [
      "/Applications/Postgres.app/Contents/Versions/latest/bin/#{tool}",
      *Dir["/Applications/Postgres.app/Contents/Versions/*/bin/#{tool}"].sort.reverse,
      tool
    ]

    candidates.find { |path| File.executable?(path) } || tool
  end

  def run_command!(command, env: {})
    puts "$ #{Shellwords.join(command)}"
    success = system(env, *command)
    return if success

    raise "Command failed: #{Shellwords.join(command)}"
  end

  def boolean_env(key, default:)
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(key, default))
  end
end

namespace :db do
  namespace :bundle do
    desc "Export full PostgreSQL database dump and optional storage archive"
    task :export, [ :dir ] => :environment do |_task, args|
      config = DbBundleTasks.db_config_hash
      DbBundleTasks.ensure_postgresql!(config)

      timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
      target_dir = Pathname(args[:dir].presence || ENV["DIR"].presence || Rails.root.join("tmp/db_bundle/#{timestamp}"))
      FileUtils.mkdir_p(target_dir)

      dump_path = target_dir.join("database.dump")
      DbBundleTasks.run_command!(
        [
          DbBundleTasks.pg_tool("pg_dump", env_key: "PG_DUMP_BIN"),
          "--format=custom",
          "--no-owner",
          "--no-privileges",
          "--file=#{dump_path}",
          *DbBundleTasks.pg_connection_args(config)
        ],
        env: DbBundleTasks.pg_password_env(config)
      )

      include_storage = DbBundleTasks.boolean_env("INCLUDE_STORAGE", default: "true")
      storage_archive = target_dir.join("storage.tar.gz")
      storage_included = false
      storage_path = Rails.root.join("storage")

      if include_storage && storage_path.directory?
        DbBundleTasks.run_command!(
          [
            "tar",
            "-czf",
            storage_archive.to_s,
            "-C",
            Rails.root.to_s,
            "storage"
          ]
        )
        storage_included = true
      end

      manifest = {
        created_at: Time.current.iso8601,
        rails_env: Rails.env,
        adapter: config[:adapter],
        database: config[:database],
        host: config[:host],
        port: config[:port],
        username: config[:username],
        dump_file: dump_path.basename.to_s,
        storage_archive: storage_included ? storage_archive.basename.to_s : nil
      }
      target_dir.join("manifest.json").write(JSON.pretty_generate(manifest))

      puts "Bundle export completed:"
      puts "  dir: #{target_dir}"
      puts "  dump: #{dump_path}"
      puts "  storage: #{storage_included ? storage_archive : 'skipped'}"
      puts "  manifest: #{target_dir.join('manifest.json')}"
    end

    desc "Import PostgreSQL dump bundle (requires FORCE=true, optionally restores storage)"
    task :import, [ :dir ] => :environment do |_task, args|
      force = DbBundleTasks.boolean_env("FORCE", default: "false")
      raise "Import is destructive. Run with FORCE=true." unless force

      target_dir = Pathname(args[:dir].presence || ENV["DIR"].presence.to_s)
      raise ArgumentError, "Provide bundle directory as DIR=... or db:bundle:import[DIR]" if target_dir.to_s.blank?
      raise ArgumentError, "Bundle directory not found: #{target_dir}" unless target_dir.directory?

      dump_path = target_dir.join("database.dump")
      raise ArgumentError, "Dump file not found: #{dump_path}" unless dump_path.file?

      config = DbBundleTasks.db_config_hash
      DbBundleTasks.ensure_postgresql!(config)

      # Keep this rake process from holding locks while pg_restore rewrites tables.
      ActiveRecord::Base.connection_pool.disconnect!

      DbBundleTasks.run_command!(
        [
          DbBundleTasks.pg_tool("pg_restore", env_key: "PG_RESTORE_BIN"),
          "--clean",
          "--if-exists",
          "--no-owner",
          "--no-privileges",
          *DbBundleTasks.pg_connection_args(config),
          dump_path.to_s
        ],
        env: DbBundleTasks.pg_password_env(config)
      )

      ActiveRecord::Base.establish_connection

      import_storage = DbBundleTasks.boolean_env("IMPORT_STORAGE", default: "true")
      storage_archive = target_dir.join("storage.tar.gz")
      replace_storage = DbBundleTasks.boolean_env("REPLACE_STORAGE", default: "true")
      storage_path = Rails.root.join("storage")

      if import_storage && storage_archive.file?
        FileUtils.rm_rf(storage_path) if replace_storage && storage_path.exist?
        DbBundleTasks.run_command!(
          [
            "tar",
            "-xzf",
            storage_archive.to_s,
            "-C",
            Rails.root.to_s
          ]
        )
      end

      puts "Bundle import completed from: #{target_dir}"
      puts "  database: restored from #{dump_path}"
      puts "  storage: #{if import_storage && storage_archive.file?
                          replace_storage ? "restored (replaced existing)" : "restored (merged)"
                         elsif import_storage
                          "archive not found, skipped"
                         else
                          "skipped by IMPORT_STORAGE=false"
                         end}"
    end
  end
end

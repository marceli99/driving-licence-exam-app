require "json"
require "zlib"
require "fileutils"

namespace :db do
  namespace :seeds do
    desc "Export current database into db/seeds/full_snapshot.json.gz (all tables except schema metadata)"
    task :export_snapshot, [ :path ] => :environment do |_task, args|
      connection = ActiveRecord::Base.connection
      default_path = Rails.root.join("db/seeds/full_snapshot.json.gz")
      path = Pathname(args[:path].presence || ENV["PATH"].presence || default_path)

      tables = connection.tables.sort - %w[schema_migrations ar_internal_metadata]
      snapshot = {
        generated_at: Time.current.iso8601,
        rails_env: Rails.env,
        adapter: connection.adapter_name,
        tables: {}
      }

      tables.each do |table_name|
        quoted_table = connection.quote_table_name(table_name)
        primary_key = connection.primary_key(table_name)
        order_clause = primary_key.present? ? " ORDER BY #{connection.quote_column_name(primary_key)}" : ""
        rows = connection.exec_query("SELECT * FROM #{quoted_table}#{order_clause}").to_a
        snapshot[:tables][table_name] = rows
        puts "Exported #{table_name}: #{rows.size} rows"
      end

      FileUtils.mkdir_p(path.dirname)
      Zlib::GzipWriter.open(path.to_s) { |gz| gz.write(JSON.generate(snapshot)) }

      puts "Seed snapshot written to: #{path}"
      puts "Run on target: FORCE=true SNAPSHOT_PATH=#{path} bin/rails db:seed"
    end

    desc "Import snapshot via db:seed (destructive, requires FORCE=true)"
    task :import_snapshot, [ :path ] => :environment do |_task, args|
      path = Pathname(args[:path].presence || ENV["PATH"].presence || Rails.root.join("db/seeds/full_snapshot.json.gz"))
      raise ArgumentError, "Snapshot file not found: #{path}" unless path.file?

      ENV["SNAPSHOT_PATH"] = path.to_s
      load Rails.root.join("db/seeds.rb")
    end
  end
end

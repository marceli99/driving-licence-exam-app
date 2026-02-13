require "json"
require "zlib"

module SeedSnapshots
  module Loader
    module_function

    SYSTEM_TABLES = %w[schema_migrations ar_internal_metadata].freeze

    def import!(path, force:)
      raise "Seed snapshot import is destructive. Run with FORCE=true." unless force

      snapshot = read_snapshot(path)
      tables_data = snapshot.fetch("tables")
      connection = ActiveRecord::Base.connection
      existing_tables = connection.tables

      tables = tables_data.keys
      missing_tables = tables.reject { |name| existing_tables.include?(name) }
      if missing_tables.any?
        raise "Snapshot contains tables missing in current schema: #{missing_tables.join(', ')}"
      end

      import_tables = tables.reject { |name| SYSTEM_TABLES.include?(name) }
      truncate_all!(connection, import_tables)

      connection.disable_referential_integrity do
        import_tables.each do |table_name|
          rows = Array(tables_data[table_name])
          next if rows.empty?

          model = anonymous_model_for(table_name)
          rows.each_slice(1000) { |slice| model.insert_all!(slice) }
        end
      end

      reset_pk_sequences!(connection, import_tables)
      puts "Loaded snapshot seeds from #{path}"
      puts "Imported tables: #{import_tables.size}"
    end

    def read_snapshot(path)
      raw = if path.to_s.end_with?(".gz")
        Zlib::GzipReader.open(path.to_s, &:read)
      else
        path.read
      end

      JSON.parse(raw)
    end

    def truncate_all!(connection, table_names)
      quoted = table_names.map { |name| connection.quote_table_name(name) }
      return if quoted.empty?

      connection.execute("TRUNCATE #{quoted.join(', ')} RESTART IDENTITY CASCADE")
    end

    def reset_pk_sequences!(connection, table_names)
      table_names.each do |table_name|
        primary_key = connection.primary_key(table_name)
        next if primary_key.blank?

        connection.reset_pk_sequence!(table_name)
      rescue StandardError => e
        warn "Failed to reset sequence for #{table_name}: #{e.message}"
      end
    end

    def anonymous_model_for(table_name)
      Class.new(ActiveRecord::Base) do
        self.table_name = table_name
        self.inheritance_column = :_type_disabled
      end
    end
  end
end

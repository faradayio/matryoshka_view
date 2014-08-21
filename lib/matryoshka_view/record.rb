require 'the_geom_geojson'
require 'the_geom_geojson/active_record'

class MatryoshkaView
  class Record < ActiveRecord::Base
    class << self
      def create_table
        activity = false
        connection_pool.with_connection do |c|
          unless table_exists?
            c.execute "CREATE TABLE #{quoted_table_name}(name text UNIQUE NOT NULL)"
            activity = true
          end
          existing_columns = column_names
          if (missing_columns = COLUMNS.keys - column_names).any?
            activity = true
            add_columns = missing_columns.map {|name| %{ADD COLUMN "#{name}" #{COLUMNS[name]}} }
            c.execute "ALTER TABLE #{quoted_table_name} #{add_columns.join(',')}"
            missing_columns.each do |name|
              case name
              when /the_geom/
                c.execute "CREATE INDEX ON #{quoted_table_name} USING gist(#{name})"
              else
                c.execute "CREATE INDEX ON #{quoted_table_name} (#{name})"
              end
            end
          end
          if activity
            c.schema_cache.clear!
            reset_column_information
          end
        end
      end

      def cleanup
        find_each do |record|
          record.destroy unless record.exists?
        end
      end
    end

    include TheGeomGeoJSON::ActiveRecord

    self.table_name = 'matryoshka_view_records'
    self.primary_key = 'name'

    COLUMNS = {
      'base'  => 'text',
      'the_geom' => 'geometry(Geometry,4326)',
      'the_geom_webmercator' => 'geometry(Geometry,3857)',
    }

    def view
      @view ||= begin
        save!
        unless exists?
          raise "missing #{name} (#{inspect})"
        end
        MatryoshkaView.new name: name, base: base, the_geom_geojson: the_geom_geojson
      end
    end

    def exists?
      MatryoshkaView.view_exists? name
    end

  end
end

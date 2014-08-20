require 'active_record'
require 'hash_digest'

require 'active_support'
require 'active_support/core_ext'

require 'matryoshka_view/version'
require 'matryoshka_view/record'

class MatryoshkaView
  class << self
    def setup
      Record.create_table
    end

    # @private
    def logger
      ActiveRecord::Base.logger
    end

    def view_exists?(*expected_names)
      result = ActiveRecord::Base.connection_pool.with_connection do |conn|
        conn.select_values <<-SQL
          SELECT 1
          FROM   pg_catalog.pg_class mv
          JOIN   pg_catalog.pg_namespace n ON n.oid = mv.relnamespace
          WHERE  n.nspname = '#{SCHEMA_NAME}'
          AND mv.oid::regclass::text IN (#{expected_names.map { |name| conn.quote(name) }.join(',')})
          AND mv.relkind = 'm'
        SQL
      end
      result.length == expected_names.length
    end
  end

  SCHEMA_NAME = 'matryoshka_view'

  attr_reader :base
  attr_reader :the_geom_geojson

  def initialize(base:, the_geom_geojson: nil)
    @base = base
    @the_geom_geojson = the_geom_geojson
  end

  def lookup(the_geom_geojson)
    # FIXME move to Record class method
    if inner = Record.where("ST_Contains(the_geom, ST_SetSRID(ST_GeomFromGeoJSON(#{quote(the_geom_geojson)}), 4326))").order("ST_Area(the_geom, false) ASC").first
      inner.view
    else
      self
    end
  end

  def spawn(the_geom_geojson)
    child = MatryoshkaView.new base: base, the_geom_geojson: the_geom_geojson
    child.spawn!
    child
  end

  def spawn!
    with_connection do |c|
      c.execute "CREATE SCHEMA IF NOT EXISTS #{SCHEMA_NAME}"
      c.execute <<-SQL
        CREATE MATERIALIZED VIEW #{name} AS (
          SELECT *
          FROM #{quoted_base_table_name}
          WHERE ST_Contains(#{quoted_base_table_name}.the_geom, ST_SetSRID(ST_GeomFromGeoJSON(#{c.quote(the_geom_geojson)}), 4326))
        )
      SQL
      record = Record.new
      record.name = name
      record.base_name = base.name
      record.save!
      record.the_geom_geojson = the_geom_geojson
      record.save!
    end
  end

  def quoted_base_table_name
    @quoted_base_table_name ||= with_connection do |c|
      base.table_name.split('.', 2).map { |part| c.quote_column_name(part) }.join('.')
    end
  end

  def name
    @name ||= if inner?
      "#{SCHEMA_NAME}.t#{HashDigest.digest3(uniq_attrs)}"
    else
      base.table_name
    end
  end

  def from_sql
    name
  end

  def name_without_schema
    @name_without_schema ||= name.split('.', 2).last
  end

  def eql?(other)
    # puts "#{uniq_attrs} <-> #{other.uniq_attrs}"
    other.is_a?(MatryoshkaView) and uniq_attrs == other.uniq_attrs
  end
  alias == eql?

  def uniq_attrs
    {
      base_table_name: base.table_name,
      the_geom_geojson: the_geom_geojson,
    }
  end

  private

  def inner?
    !the_geom_geojson.nil?
  end

  # db helper to make sure we immediately return connections to pool
  # @private
  [
    # :execute,
    :quote,
    # :quote_column_name,
    # :quote_table_name,
    # :select_all,
    # :select_rows,
    # :select_value,
    # :select_values,
  ].each do |method_id|
    define_method method_id do |sql|
      with_connection do |conn|
        conn.send method_id, sql
      end
    end
  end

  # db helper to make sure we immediately return connections to pool
  # @private
  def with_connection
    base.connection_pool.with_connection do |conn|
      yield conn
    end
  end

end
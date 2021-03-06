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
          WHERE
            mv.oid::regclass::text IN (#{expected_names.map { |name| conn.quote(name) }.join(',')})
            AND mv.relkind = 'r'
        SQL
      end
      result.length == expected_names.length
    end
  end

  SCHEMA_NAME = 'matryoshka_view'

  attr_reader :base
  attr_reader :geom_source

  def initialize(base:, geom_source: nil, the_geom_geojson: nil, name: nil)
    @base = base
    @the_geom_geojson = the_geom_geojson
    @geom_source = geom_source
    @name = name
  end

  def lookup(geom_source: nil, the_geom_geojson: nil)
    # FIXME move to Record class method
    hit = with_connection do |c|
      if geom_source
        if geom_source.changed?
          Record.where("(base = #{c.quote base}) AND (the_geom && #{c.quote geom_source.the_geom}) AND ST_Contains(ST_Buffer(the_geom, 0.00001), #{c.quote geom_source.the_geom})").order("ST_Area(the_geom, false) ASC").first
        else
          Record.where("(base = #{c.quote base}) AND (the_geom && (SELECT the_geom FROM #{geom_source.class.quoted_table_name} WHERE id = #{c.quote(geom_source.id)})) AND ST_Contains(ST_Buffer(the_geom, 0.00001), (SELECT the_geom FROM #{geom_source.class.quoted_table_name} WHERE id = #{c.quote(geom_source.id)}))").order("ST_Area(the_geom, false) ASC").first
        end
      elsif the_geom_geojson
        Record.where("(base = #{c.quote base}) AND (the_geom && ST_SetSRID(ST_GeomFromGeoJSON(#{c.quote the_geom_geojson}), 4326)) AND ST_Contains(ST_Buffer(the_geom, 0.00001), ST_SetSRID(ST_GeomFromGeoJSON(#{c.quote the_geom_geojson}), 4326))").order("ST_Area(the_geom, false) ASC").first
      else
        raise "expecting geom_source or the_geom_geojson"
      end
    end
    hit.try(:view) || self
  end

  def spawn(attrs)
    child = MatryoshkaView.new attrs.reverse_merge(base: base)
    child.spawn!
    child
  end

  def spawn!
    with_connection do |c|
      c.execute "CREATE SCHEMA IF NOT EXISTS #{SCHEMA_NAME}"
      c.execute <<-SQL
        CREATE TABLE #{name} (LIKE #{quoted_base} INCLUDING ALL)
      SQL
      c.execute <<-SQL
        INSERT INTO #{name}
          SELECT *
          FROM #{quoted_base}
          WHERE ST_Contains(ST_SetSRID(ST_GeomFromGeoJSON(#{c.quote(the_geom_geojson)}), 4326), #{quoted_base}.the_geom)
      SQL
      record = Record.new
      record.name = name
      record.base = base
      record.save!
      record.the_geom_geojson = the_geom_geojson
      record.save!
    end
  end

  def the_geom_geojson
    @the_geom_geojson ||= geom_source.try :the_geom_geojson
  end

  def quoted_base
    @quoted_base ||= with_connection do |c|
      base.split('.', 2).map { |part| c.quote_column_name(part) }.join('.')
    end
  end

  def name
    @name ||= if inner?
      "#{SCHEMA_NAME}.t#{HashDigest.digest3(uniq_attrs)}"
    else
      base
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
      base_table_name: base,
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
    ActiveRecord::Base.connection_pool.with_connection do |conn|
      yield conn
    end
  end

end

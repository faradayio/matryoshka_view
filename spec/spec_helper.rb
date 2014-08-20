$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'pry'

require 'logger'
require 'fileutils'

log_dir = File.expand_path('../../log', __FILE__)
FileUtils.mkdir_p log_dir

logger = Logger.new(File.join(log_dir, 'test.log'))
logger.level = Logger::DEBUG

dbname = 'matryoshka_view_test'
unless ENV['FAST'] == 'true'
  system 'dropdb', '--if-exists', dbname
  system 'createdb', dbname
  system 'psql', dbname, '--command', 'CREATE EXTENSION postgis'
  system 'psql', dbname, '--command', 'CREATE TABLE places (id serial primary key, the_geom geometry(Geometry,4326), the_geom_webmercator geometry(Geometry,3857))'
end

require 'active_record'

ActiveRecord::Base.logger = logger

ActiveRecord::Base.establish_connection "postgresql://127.0.0.1/#{dbname}"

# http://gray.fm/2013/09/17/unknown-oid-with-rails-and-postgresql/
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.tap do |klass|
  klass::OID.register_type('geometry', klass::OID::Identity.new)
end

require 'rspec'
require 'database_cleaner'
require 'the_geom_geojson/examples'

DatabaseCleaner.strategy = :deletion, {except: %w{ spatial_ref_sys }}

RSpec.configure do |config|
  config.fail_fast = true

  config.before(:suite) do
    ActiveRecord::Base.connection.execute "DROP SCHEMA IF EXISTS #{MatryoshkaView::SCHEMA_NAME} CASCADE"
  end

  config.before(:each) do
    ActiveRecord::Base.connection.execute "DROP SCHEMA IF EXISTS #{MatryoshkaView::SCHEMA_NAME} CASCADE"
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

require 'matryoshka_view'

MatryoshkaView.setup

class Place < ActiveRecord::Base
  include TheGeomGeoJSON::ActiveRecord
end

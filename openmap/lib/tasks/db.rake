namespace :db do

  # this will completely drop and re-create the database by re-running all migrations
  task :recreate => [ 'db:migrate:reset', 'db:seed' ]


  # non database drop rebuild from schema.rb - can be run while nginx holds database connection
  task :rebuild => [ 'db:rebuild_from_schema', 'db:schema:load', 'db:seed' ]


  # TODO: consider recreate the database from structure.sql, with rake db:structure:load above - the more complete schema with constraints
  # TODO: loading the census data generates multiple PostgreSQL OID warnings, which are safe to ignore, but will be nice to chase this down
  task :rebuild_from_schema => :environment do
    ActiveRecord::Base.establish_connection
    tables = ActiveRecord::Base.connection.tables - ["spatial_ref_sys"]
    tables.each{ |table| ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{table}") }
  end

end
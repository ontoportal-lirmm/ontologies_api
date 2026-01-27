require 'active_record'
require_relative '../config/relationalDatabase'

namespace :db do
  desc "Create the RelationalDatabase"
  task :create do
    RelationalDatabase.connect!
    puts "RelationalDatabase created (or already exists via Docker)"
  end

  desc "Run migrations"
  task :migrate do
    RelationalDatabase.connect!
    ActiveRecord::MigrationContext.new("db/migrate").migrate
    puts "Migrations completed"
  end

  desc "Rollback the last migration"
  task :rollback do
    RelationalDatabase.connect!
    ActiveRecord::MigrationContext.new("db/migrate").rollback
    puts "Rollback completed"
  end

  desc "Drop the RelationalDatabase"
  task :drop do
    puts "Drop the RelationalDatabase manually or recreate the Docker container"
  end

  desc "Reset the RelationalDatabase (drop, create, migrate)"
  task reset: [:drop, :create, :migrate]

  desc "Show migration status"
  task :status do
    RelationalDatabase.connect!
    ActiveRecord::MigrationContext.new("db/migrate").migrations_status.each do |status, version, name|
      puts "#{status.center(8)} #{version.ljust(14)} #{name}"
    end
  end

  desc "Seed the RelationalDatabase"
  task :seed do
    RelationalDatabase.connect!
    seed_file = File.join(File.dirname(__FILE__), '..', 'db', 'seeds.rb')
    load(seed_file) if File.exist?(seed_file)
    puts "Seeding completed"
  end
end

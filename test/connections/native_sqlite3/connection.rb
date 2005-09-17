print "Using native SQLite3\n"
require 'logger'
ActiveRecord::Base.logger = Logger.new("debug.log")

class SqliteError < StandardError
end

BASE_DIR = File.expand_path(File.dirname(__FILE__) + '/../../fixtures')
sqlite_test_db  = "#{BASE_DIR}/activerecord_paranoid.sqlite3"

def make_connection(clazz, db_file, db_definitions_file)
  unless File.exist?(db_file)
    puts "SQLite3 database not found at #{db_file}. Rebuilding it."
    sqlite_command = %Q{sqlite3 #{db_file} "create table a (a integer); drop table a;"}
    puts "Executing '#{sqlite_command}'"
    raise SqliteError.new("Seems that there is no sqlite3 executable available") unless system(sqlite_command)
    clazz.establish_connection(
        :adapter => "sqlite3",
        :dbfile  => db_file)
    script = File.read("#{BASE_DIR}/db_definitions/#{db_definitions_file}")
    # SQLite-Ruby has problems with semi-colon separated commands, so split and execute one at a time
    script.split(';').each do
      |command|
      clazz.connection.execute(command) unless command.strip.empty?
    end
  else
    clazz.establish_connection(
        :adapter => "sqlite3",
        :dbfile  => db_file)
  end
end

make_connection(ActiveRecord::Base, sqlite_test_db, 'sqlite.sql')

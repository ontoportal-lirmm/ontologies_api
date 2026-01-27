require 'active_record'
require 'yaml'
require 'erb'

module RelationalDatabase
  class << self
    def connect!
      db_config = YAML.safe_load(
        ERB.new(File.read(config_file)).result,
        aliases: true
      )

      environment = ENV.fetch('RACK_ENV', 'development')
      ActiveRecord::Base.establish_connection(db_config[environment])

      puts "(API) >> Connected to PostgreSQL database: #{db_config[environment]['database']}"
    end

    def config_file
      File.expand_path('database.yml', __dir__)
    end
  end
end

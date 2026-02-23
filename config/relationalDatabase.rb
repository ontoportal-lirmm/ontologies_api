require 'active_record'
require 'yaml'
require 'erb'

module RelationalDatabase
  class << self
    def connect!
      ActiveRecord::Base.establish_connection(load_config[environment])
      puts "(API) >> Connected to PostgreSQL database: #{ActiveRecord::Base.connection_db_config.database}"
    end

    def create!
      config = load_config[environment]
      database_name = config['database']
      
      # Connect to the default 'postgres' database to create the new one
      admin_config = config.merge('database' => 'postgres')
      ActiveRecord::Base.establish_connection(admin_config)
      
      begin
        ActiveRecord::Base.connection.create_database(database_name)
        puts "(API) >> Created PostgreSQL database: #{database_name}"
      rescue ActiveRecord::DatabaseAlreadyExists
        puts "(API) >> PostgreSQL database already exists: #{database_name}"
      ensure
        ActiveRecord::Base.remove_connection
      end
    end

    def config_file
      File.expand_path('database.yml', __dir__)
    end

    private

    def load_config
      @load_config ||= YAML.safe_load(
        ERB.new(File.read(config_file)).result,
        aliases: true
      )
    end

    def environment
      ENV.fetch('RACK_ENV', 'development')
    end
  end
end

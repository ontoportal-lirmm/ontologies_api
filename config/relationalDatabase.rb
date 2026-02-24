require 'active_record'
require 'yaml'
require 'erb'

module RelationalDatabase
  class << self
    def connect!
      env = environment
      config = load_config
      
      ActiveRecord::Base.configurations = config
      
      begin
        ActiveRecord::Base.establish_connection(env.to_sym)
        puts "(API) >> Connected to PostgreSQL database: #{ActiveRecord::Base.connection_db_config.database} (env: #{env})"
      rescue => e
        puts "(API) >> ERROR: Failed to connect to database for env '#{env}': #{e.message}"
        puts "(API) >> Available configs: #{ActiveRecord::Base.configurations.configs_for.map(&:env_name).inspect}"
        raise e
      end
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
      @load_config ||= begin
        YAML.safe_load(
          ERB.new(File.read(config_file)).result,
          aliases: true
        )
      end
    end

    def environment
      ENV.fetch('RACK_ENV', 'development')
    end
  end
end

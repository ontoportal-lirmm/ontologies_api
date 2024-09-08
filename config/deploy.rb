set :repo_url, "git@github.com:biodivportal/ontologies_api.git"
set :user, 'ontoportal'

set :deploy_to, '/srv/ontoportal/ontologies_api'


set :stages, %w[appliance]
set :default_stage, 'appliance'
set :stage, 'appliance'
set :application, 'ontologies_api'

# SSH parameters
set :ssh_port, 22
set :pty, true

# Source code
set :repository_cache, "git_cache"
set :deploy_via, :remote_cache
set :ssh_options, { :forward_agent => true }

# Linked files and directories
append :linked_files, "config/environments/appliance.rb"

append :linked_dirs, 'logs', '.bundle'
set :keep_releases, 2



# frozen_string_literal: true

require 'mina/bundler'
require 'mina/rails'
require 'mina/git'
require 'mina/rvm'
require 'mina/puma'
require 'mina/nginx'

# multi env
case ENV['to']
when 'something'
  nil
else
  set :application_name, 'rails6boilerplate'
  set :domain, 'TODO'
  set :deploy_to, '/home/ubuntu/rails6boilerplate'
  set :repository, 'git@bitbucket.org:TODO_USERNAME/TODO_PROJECT_NAME.git'
  set :branch, 'staging'
  set :user, 'ubuntu'
  set :keep_releases, 1
  set :identity_file, 'terraform/staging/ssh_keys/rails6boilerplate-staging'
  set :rails_env, 'staging'
end

set :shared_dirs, fetch(:shared_dirs, []).push('tmp/pids', 'tmp/sockets')
set :shared_files, fetch(:shared_files, []).push('config/master.key', 'config/database.yml', 'config/puma.rb')

task :remote_environment do
  invoke :'rvm:use', '2.6.4@rails6boilerplate'
end

# Put any custom commands you need to run at setup
# All paths in `shared_dirs` and `shared_paths` will be created on their own.
task :setup do
  invoke :'rvm:use', '2.6.4@rails6boilerplate'
  command 'gem install bundler'
  command "aws s3 cp s3://--secrets/master.key /home/ubuntu//shared/config/master.key"
  system "scp -i  /Users/admin/Documents/github/rails6boilerplate/lib/server_configs/#{fetch(:rails_env)}_puma.rb @:/config/puma.rb"
  system "scp -i  /Users/admin/Documents/github/rails6boilerplate/lib/server_configs/#{fetch(:rails_env)}_database.yml @:/config/database.yml"
end

desc 'Deploys the current version to the server.'
task :deploy do
  # uncomment this line to make sure you pushed your local branch to the remote origin
  # invoke :'git:ensure_pushed'
  deploy do
    # Put things that will set up an empty directory into a fully set-up
    # instance of your project.
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'rails:db_create'
    invoke :'rails:db_migrate'
    invoke :'rails:assets_precompile'
    invoke :'deploy:cleanup'

    on :launch do
      in_path(fetch(:current_path)) do
        invoke :'rvm:use', '2.6.4@rails6boilerplate'
        # invoke :'puma:start' # on first launch
        invoke :'puma:hard_restart'
        invoke :'nginx:reload'
      end
    end
  end
end

task :console do
  in_path(fetch(:current_path)) do
    invoke :'rvm:use', '2.6.4@rails6boilerplate'
    command "RAILS_ENV= bundle exec rails console"
  end
end

task :puma_start do
  in_path(fetch(:current_path)) do
    invoke :'puma:start'
  end
end

task :reseed do
  in_path(fetch(:current_path)) do
    invoke :'rvm:use', '2.6.4@rails6boilerplate'
    command "RAILS_ENV= DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rake db:drop"
    command "RAILS_ENV= DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rake db:create"
    command "RAILS_ENV= DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rake db:migrate"
    command "RAILS_ENV= DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rake db:seed"
    # invoke :'sitemap:refresh'
  end
end

task :reload_nginx do
  in_path(fetch(:current_path)) do
    invoke :'nginx:reload'
  end
end

task :tail do
  in_path(fetch(:current_path)) do
    command "tail -f /home/ubuntu//shared/log/.log"
  end
end

task :tail_nginx_access do
  in_path(fetch(:current_path)) do
    command 'tail -f /var/log/nginx/access.log'
  end
end

task :tail_nginx_error do
  in_path(fetch(:current_path)) do
    command 'tail -f /var/log/nginx/error.log'
  end
end

task :grep do
  in_path(fetch(:current_path)) do
    command "cat /home/ubuntu//shared/log/.log | grep "
  end
end


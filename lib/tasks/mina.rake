# frozen_string_literal: true

namespace :mina do
  desc 'Create server_database.yml'
  task :create_server_database_yml, [:env] => :environment do |task, args|
    puts "START - Create #{args[:env]}_database.yml"
    FileUtils.mkdir_p "#{Rails.root.join('server_configs')}"
    filepath = Rails.root.join('server_configs', "#{args[:env]}_database.yml")
    file = File.open(filepath, 'w')
    file.puts <<~MSG
      default: &default
        adapter: mysql2
        encoding: utf8mb4
        pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
      #{args[:env]}:
        <<: *default
        username: ubuntu
        database: #{PROJECT_NAME}#{args[:env]}
        password: <%= Rails.application.credentials.dig(:#{args[:env]}, :database, :password) %>
    MSG
    file.close
    puts "END - Create #{args[:env]}_database.yml"
  end

  desc 'Create server_puma.rb'
  task :create_server_puma_rb, [:env] => :environment do |task, args|
    puts "START - Create #{args[:env]}_puma.rb"
    filepath = Rails.root.join('server_configs', "#{args[:env]}_puma.rb")
    file = File.open(filepath, 'w')
    file.puts <<~MSG
      # frozen_string_literal: true

      max_threads_count = ENV.fetch('RAILS_MAX_THREADS') { 5 }
      min_threads_count = ENV.fetch('RAILS_MIN_THREADS') { max_threads_count }
      threads min_threads_count, max_threads_count

      port ENV.fetch('PORT') { 3000 }

      environment ENV.fetch('RAILS_ENV') { '#{args[:env]}' }

      bind 'unix:///home/ubuntu/#{PROJECT_NAME}/shared/tmp/sockets/puma.sock'
      pidfile '/home/ubuntu/#{PROJECT_NAME}/shared/tmp/pids/puma.pid'
      state_path '/home/ubuntu/#{PROJECT_NAME}/shared/tmp/sockets/puma.state'
      directory '/home/ubuntu/#{PROJECT_NAME}/current'

      daemonize true

      activate_control_app 'unix:///home/ubuntu/#{PROJECT_NAME}/shared/tmp/sockets/pumactl.sock'

      prune_bundler

      plugin :tmp_restart
    MSG
    file.close
    puts "END - Create #{args[:env]}_puma.rb"
  end

  desc 'Create deploy.rb'
  task :create_deploy_rb, [:env] => :environment do |task, args|
    puts "START - Create config/deploy.rb"
    filepath = "#{Rails.root.join('config')}/deploy.rb"
    ruby_gemset = File.read("#{Rails.root}/.ruby-version").chomp
    abort('config/deploy.rb file exist! Look for "# multi env" and add the configurations for your new environment!') if File.exist?(filepath)
    file = File.open(filepath, 'w')
    file.puts <<~MSG
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
        set :application_name, '#{PROJECT_NAME}'
        set :domain, 'TODO'
        set :deploy_to, '/home/ubuntu/#{PROJECT_NAME}'
        set :repository, 'git@bitbucket.org:TODO_USERNAME/TODO_PROJECT_NAME.git'
        set :branch, '#{args[:env]}'
        set :user, 'ubuntu'
        set :keep_releases, 1
        set :identity_file, 'terraform/#{args[:env]}/ssh_keys/#{PROJECT_NAME}-#{args[:env]}'
        set :rails_env, '#{args[:env]}'
      end

      set :shared_dirs, fetch(:shared_dirs, []).push('tmp/pids', 'tmp/sockets')
      set :shared_files, fetch(:shared_files, []).push('config/master.key', 'config/database.yml', 'config/puma.rb')

      task :remote_environment do
        invoke :'rvm:use', '#{ruby_gemset}'
      end

      # Put any custom commands you need to run at setup
      # All paths in `shared_dirs` and `shared_paths` will be created on their own.
      task :setup do
        invoke :'rvm:use', '#{ruby_gemset}'
        command 'gem install bundler'
        command "aws s3 cp s3://#{fetch(:application_name)}-#{fetch(:rails_env)}-secrets/master.key /home/ubuntu/#{fetch(:application_name)}/shared/config/master.key"
        system "scp -i #{fetch(:identity_file)} #{File.expand_path('../server_configs/#{fetch(:rails_env)}_puma.rb', File.dirname(__FILE__))} #{fetch(:user)}@#{fetch(:domain)}:#{fetch(:shared_path)}/config/puma.rb"
        system "scp -i #{fetch(:identity_file)} #{File.expand_path('../server_configs/#{fetch(:rails_env)}_database.yml', File.dirname(__FILE__))} #{fetch(:user)}@#{fetch(:domain)}:#{fetch(:shared_path)}/config/database.yml"
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
              invoke :'rvm:use', '#{ruby_gemset}'
              # invoke :'puma:start' # on first launch
              invoke :'puma:hard_restart'
              invoke :'nginx:reload'
            end
          end
        end
      end

      task :console do
        in_path(fetch(:current_path)) do
          invoke :'rvm:use', '#{ruby_gemset}'
          command "RAILS_ENV=#{fetch(:rails_env)} bundle exec rails console"
        end
      end

      task :puma_start do
        in_path(fetch(:current_path)) do
          invoke :'puma:start'
        end
      end

      task :reseed do
        in_path(fetch(:current_path)) do
          invoke :'rvm:use', '#{ruby_gemset}'
          command "RAILS_ENV=#{fetch(:rails_env)} DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rake db:drop"
          command "RAILS_ENV=#{fetch(:rails_env)} DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rake db:create"
          command "RAILS_ENV=#{fetch(:rails_env)} DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rake db:migrate"
          command "RAILS_ENV=#{fetch(:rails_env)} DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rake db:seed"
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
          command "tail -f /home/ubuntu/#{fetch(:application_name)}/shared/log/#{fetch(:rails_env)}.log"
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
          command "cat /home/ubuntu/#{fetch(:application_name)}/shared/log/#{fetch(:rails_env)}.log | grep #{ENV['cmd']}"
        end
      end

    MSG
    file.close
    puts "ENV - Create config/deploy.rb"
  end
end
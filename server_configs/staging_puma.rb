# frozen_string_literal: true

max_threads_count = ENV.fetch('RAILS_MAX_THREADS') { 5 }
min_threads_count = ENV.fetch('RAILS_MIN_THREADS') { max_threads_count }
threads min_threads_count, max_threads_count

port ENV.fetch('PORT') { 3000 }

environment ENV.fetch('RAILS_ENV') { 'staging' }

bind 'unix:///home/ubuntu/rails6boilerplate/shared/tmp/sockets/puma.sock'
pidfile '/home/ubuntu/rails6boilerplate/shared/tmp/pids/puma.pid'
state_path '/home/ubuntu/rails6boilerplate/shared/tmp/sockets/puma.state'
directory '/home/ubuntu/rails6boilerplate/current'

daemonize true

activate_control_app 'unix:///home/ubuntu/rails6boilerplate/shared/tmp/sockets/pumactl.sock'

prune_bundler

plugin :tmp_restart

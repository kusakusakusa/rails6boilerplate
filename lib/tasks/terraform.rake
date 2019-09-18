# frozen_string_literal: true

namespace :terraform do
  desc 'Checks before proceeding'
  task :checks, [:env, :aws_profile, :region] => :environment do |task, args|
    puts 'START - Checks necessary conditions before proceeding'
    abort('awscli not installed!') if `type -a aws`.blank?
    abort('~/.aws/credentials does not exist!') unless File.exist?("#{ENV['HOME']}/.aws/credentials")
    abort("#{args[:aws_profile]} does not have aws_access_key_id properly setup!") if `aws --profile #{args[:aws_profile]} configure get aws_access_key_id`.chomp.blank?
    abort("#{args[:aws_profile]} does not have aws_secret_access_key properly setup!") if `aws --profile #{args[:aws_profile]} configure get aws_secret_access_key`.chomp.blank?
    abort("Opt-in region #{args[:region]} are not supported!") if %w[
      me-south-1
      ap-east-1
    ].include? args[:region]
    abort('Invalid aws region!') unless %w[
      us-east-1
      us-east-2
      us-west-1
      us-west-2
      ca-central-1
      eu-central-1
      eu-west-1
      eu-west-2
      eu-west-3
      eu-north-1
      ap-northeast-1
      ap-northeast-2
      ap-northeast-3
      ap-southeast-1
      ap-southeast-2
      ap-south-1
      sa-east-1
    ].include? args[:region]
    abort("No database password in credentials file for #{args[:env]} environment") unless Rails.application.credentials.dig(args[:env].to_sym, :database, :password)
    puts 'END - Checks necessary conditions before proceeding'
  end

  desc 'Create env folder'
  task :create_env_folders, [:env] => :environment do |task, args|
    puts "START - Create #{args[:env]} folders in terraform"
    FileUtils.mkdir_p "#{Rails.root.join('terraform', args[:env])}"
    FileUtils.mkdir_p "#{Rails.root.join('terraform', args[:env], 'ssh_keys')}"
    FileUtils.mkdir_p "#{Rails.root.join('terraform', args[:env], 'scripts')}"
    puts "END - Create #{args[:env]} folders in terraform"
  end

  desc 'Generate private/public key'
  task :generate_ssh_keys, [:env] => :environment do |task, args|
    # these keys will be used for:
    # 1. generating aws keypair
    # 2. authentication key for private git repository
    private_key_file_name = "#{Rails.application.class.module_parent_name.downcase}-#{args[:env]}"
    filepath = "#{Rails.root.join('terraform', args[:env], 'ssh_keys')}/#{private_key_file_name}"
    puts "START - Create private/public keys for #{args[:env]}"

    if File.exist? filepath
      puts 'Private key already created'
    else
      `ssh-keygen -t rsa -f #{filepath} -C #{private_key_file_name}`
      puts "chmod 400 private and public keys for #{args[:env]}"
      `chmod 400 #{filepath}`
      `chmod 400 #{filepath}.pub`
    end

    puts "END - Create private/public keys for #{args[:env]}"
  end

  desc 'Copy template files'
  task :copy_template_files, [:env] => :environment do |task, args|
    puts "START - Copy files in `templates` folder into #{args[:env]} folder in terraform"
    FileUtils.cp_r "#{Rails.root.join('terraform', 'templates')}/.", Rails.root.join('terraform', args[:env])
    puts "END - Copy files in `templates` folder into #{args[:env]} folder in terraform"
  end

  desc 'Create tfstate_bucket'
  task :create_tfstate_bucket, [:env, :aws_profile, :region] => :environment do |task, args|
    # create terraform backend s3 bucket via aws-cli
    # aws-cli is assumed to be present on local machine

    tfstate_bucket_name = "#{Rails.application.class.module_parent_name.downcase}-#{args[:env]}-tfstate"
    tfstate_bucket = `aws s3 --profile #{args[:aws_profile]} ls | grep " #{tfstate_bucket_name}$"`.chomp
    if tfstate_bucket.blank?
      puts "Creating Terraform state bucket (#{tfstate_bucket_name})"
      `aws s3api create-bucket --bucket #{tfstate_bucket_name} --region #{args[:region]} --profile #{args[:aws_profile]} --create-bucket-configuration LocationConstraint=#{args[:region]}`

      sleep 2

      puts 'Uploading empty tfstate file'
      blank_filepath = Rails.root.join('tmp/tfstate')
      `touch #{blank_filepath}`
      `aws s3 cp #{blank_filepath} s3://#{tfstate_bucket_name}/terraform.tfstate --profile #{args[:aws_profile]}`
      File.delete(blank_filepath)
    else
      puts "Terraform state bucket (#{tfstate_bucket_name}) already created!"
    end

    puts "Enabling/overwriting versioning for #{tfstate_bucket_name}"
    `aws s3api put-bucket-versioning --bucket #{tfstate_bucket_name} --profile #{args[:aws_profile]} --versioning-configuration Status=Enabled`

    tmp_versioning_filepath = Rails.root.join('tmp/tf_state_encryption_rule.json')
    puts "Enabling/overwriting encryption for #{tfstate_bucket_name}"
    file = File.open(tmp_versioning_filepath, 'w')
    file.puts <<~MSG
      {
        "Rules": [
          {
            "ApplyServerSideEncryptionByDefault": {
              "SSEAlgorithm": "AES256"
            }
          }
        ]
      }
    MSG
    file.close
    `aws s3api put-bucket-encryption --bucket #{tfstate_bucket_name} --profile #{args[:aws_profile]} --server-side-encryption-configuration file://#{tmp_versioning_filepath}`
    File.delete(tmp_versioning_filepath)

    puts "Enabling/overwriting lifecycle for #{tfstate_bucket_name}"
    tmp_lifecycle_filepath = Rails.root.join('tmp/tf_state_lifecycle_rule.json')
    file = File.open(tmp_lifecycle_filepath, 'w')
    file.puts <<~MSG
      {
          "Rules": [
              {
                  "ID": "Remove non current version tfstate files",
                  "Status": "Enabled",
                  "Prefix": "",
                  "NoncurrentVersionExpiration": {
                      "NoncurrentDays": 30
                  }
              }
          ]
      }
    MSG
    file.close
    `aws s3api put-bucket-lifecycle-configuration --bucket #{tfstate_bucket_name} --profile #{args[:aws_profile]} --lifecycle-configuration file://#{tmp_lifecycle_filepath}`
    File.delete(tmp_lifecycle_filepath)
  end

  desc 'Create setup.tf'
  task :create_setup_tf, [:env, :region] => :environment do |task, args|
    puts "START - Create setup.tf for #{args[:env]}"
    file = File.open(Rails.root.join('terraform', args[:env], 'setup.tf'), 'w')
    file.puts <<~MSG
      # download all necessary plugins for terraform
      # set versions
      provider "aws" {
        version = "~> 2.24"
        region = "#{args[:region]}"
        # shared_credentials_file and profile NOT WORKING
        # need to pass AWS_SHARED_CREDENTIALS_FILE
        # and AWS_PROFILE
      }

      terraform {
        required_version = "~> 0.12.0"
        backend "s3" {
          bucket = "#{Rails.application.class.module_parent_name.downcase}-#{args[:env]}-tfstate"
          key = "terraform.tfstate"
          region = "#{args[:region]}"
        }
      }

      provider "null" {
        version = "~> 2.1"
      }

    MSG
    file.close
    puts "END - Create setup.tf for #{args[:env]}"
  end

  desc 'Create variables.tf'
  task :create_variables_tf, [:env, :region] => :environment do |task, args|
    puts "START - Create variables.tf for #{args[:env]}"
    file = File.open(Rails.root.join('terraform', args[:env], 'variables.tf'), 'w')
    file.puts <<~MSG
      variable "project_name" {
        type = string
        default = "#{Rails.application.class.module_parent_name.downcase}"
      }

      variable "region" {
        type = string
        default = "#{args[:region]}"
      }

      variable "env" {
        type = string
        default = "#{args[:env]}"
      }
    MSG
    file.close
    puts "END - Create variables.tf for #{args[:env]}"
  end

  # for pushing terraform errored.tfstate in the event of
  # losing internet connection during deployment
  # with a remote backend
  desc 'Create push_error_state.sh'
  task :create_push_error_state_sh, [:env, :aws_profile] => :environment do |task, args|
    puts "START - Create push_error_state.sh for #{args[:env]}"
    filepath = Rails.root.join('terraform', args[:env], 'push_error_state.sh')
    file = File.open(filepath, 'w')
    file.puts <<~MSG
      #!/usr/bin/env bash

      SCRIPT_PATH=$(dirname `which $0`)

      echo $SCRIPT_PATH

      cp $SCRIPT_PATH/../../config/master.key $SCRIPT_PATH/master.key
      cp $HOME/.aws/credentials $SCRIPT_PATH/awscredentials

      docker build \
        -t \
        #{Rails.application.class.module_parent_name.downcase}-#{args[:env]}:latest \
        $SCRIPT_PATH

      echo 'terraform push error.tfstate'
      docker run \
        -it \
        --rm \
        --env AWS_SHARED_CREDENTIALS_FILE=awscredentials \
        --env AWS_PROFILE=#{args[:aws_profile]} \
        -v $SCRIPT_PATH:/workspace \
        #{Rails.application.class.module_parent_name.downcase}-#{args[:env]} \
        state push errored.tfstate

      rm $SCRIPT_PATH/master.key
      rm $SCRIPT_PATH/awscredentials
    MSG
    file.close
    system("chmod +x #{filepath}")
    puts "END - Create push_error_state.sh for #{args[:env]}"
  end

  desc 'Create startup.sh'
  task :create_startup_sh, [:env, :aws_profile] => :environment do |task, args|
    puts "START - Create startup.sh for #{args[:env]}"
    db_password = Rails.application.credentials.dig(args[:env].to_sym, :database, :password)
    filepath = Rails.root.join('terraform', args[:env], 'startup.sh')
    file = File.open(filepath, 'w')
    file.puts <<~MSG
      #!/usr/bin/env bash

      # install packages
      sudo apt-get -y update
      sudo apt-get update -y && sudo apt-get upgrade -y && sudo apt-get install nginx gnupg2 nodejs build-essential mysql-server libmysqlclient-dev awscli npm sendmail -y

      # copy keys files
      aws s3 cp s3://#{Rails.application.class.module_parent_name.downcase}-#{args[:env]}-secrets/#{Rails.application.class.module_parent_name.downcase}-#{args[:env]} /home/ubuntu/.ssh/id_rsa
      if [ $? -eq 0 ]
      then
        echo 'Successfully copied private key'
      else
        echo 'Fail to copy private key'
        exit 1
      fi

      aws s3 cp s3://#{Rails.application.class.module_parent_name.downcase}-#{args[:env]}-secrets/#{Rails.application.class.module_parent_name.downcase}-#{args[:env]}.pub /home/ubuntu/.ssh/id_rsa.pub
      if [ $? -eq 0 ]
      then
        echo 'Successfully copied public key'
      else
        echo 'Fail to copy public key'
        exit 1
      fi
      chmod 400 /home/ubuntu/.ssh/id_rsa
      chmod 400 /home/ubuntu/.ssh/id_rsa.pub

      echo 'Install rvm'
      echo 'gem: --no-document' > .gemrc # remove documentation
      gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
      \curl -sSL https://get.rvm.io | bash # download rvm
      source /home/ubuntu/.rvm/scripts/rvm # make rvm available in current session

      echo 'Install ruby-2.6.4'
      rvm install 2.6.4 # install the ruby version

      echo 'Set ruby-2.6.4 as default'
      rvm default use 2.6.4

      echo 'Install bundler'
      gem install bundler # install bundler

      echo 'Install yarn via npm'
      sudo npm install -g yarn
      if [ $? -ne 0 ]
      then
        echo 'Fail to install npm'
        exit 1
      fi

      echo 'Enable swap for assets compilation'
      # https://www.digitalocean.com/community/tutorials/how-to-add-swap-space-on-ubuntu-16-04
      sudo fallocate -l 1G /swapfile
      sudo chmod 600 /swapfile
      sudo mkswap /swapfile
      sudo swapon /swapfile
      sudo cp /etc/fstab /etc/fstab.bak
      echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

      echo 'Overwrite nginx default available site'
      sudo chgrp $(whoami) /etc/nginx/sites-available/default
      sudo chown $(whoami) /etc/nginx/sites-available/default
      sudo chmod +w /etc/nginx/sites-available/default
      cat > /etc/nginx/sites-available/default <<EOF
      upstream backend {
        server unix:///home/ubuntu/#{Rails.application.class.module_parent_name.downcase}/shared/tmp/sockets/puma.sock fail_timeout=0;
      }

      # no server_name, routes to default this default server directive
      server {
        listen 80;
        client_max_body_size 10m;

        location / {
          proxy_pass http://backend;
          proxy_redirect off;
          proxy_set_header   Host             \$host;
          proxy_set_header   X-Real-IP        \$remote_addr;
          proxy_set_header   X-Forwarded-For  \$proxy_add_x_forwarded_for;
          proxy_pass_request_headers      on;
        }

        location ~ ^/(assets|packs)/ {
          root /home/ubuntu/#{Rails.application.class.module_parent_name.downcase}/current/public;
          expires max;
          add_header Cache-Control public;
          gzip_static on;
          #add_header ETag "";
          break;
        }
      }
      EOF

      echo 'Installing mysql'
      echo 'Set password for root user'
      sudo mysql -e "SET PASSWORD FOR root@localhost = PASSWORD('#{db_password}');FLUSH PRIVILEGES;"

      echo 'Delete anonymous users'
      sudo mysql -e "DELETE FROM mysql.user WHERE User='';"

      echo 'Ensure the root user can not log in remotely'
      sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"

      echo 'Remove the test database'
      sudo mysql -e "DROP DATABASE test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"

      echo 'Create curent user to remove sudo requirement'
      sudo mysql -u root -p#{db_password} -e "CREATE USER 'ubuntu'@'localhost' IDENTIFIED BY '#{db_password}';GRANT ALL PRIVILEGES ON *.* TO 'ubuntu'@'localhost';FLUSH PRIVILEGES;"

      echo 'Setup logrotate'
      sudo touch /etc/logrotate.d/#{Rails.application.class.module_parent_name.downcase}
      sudo tee /etc/logrotate.d/#{Rails.application.class.module_parent_name.downcase} > /dev/null <<EOF
      /home/ubuntu/#{Rails.application.class.module_parent_name.downcase}/shared/log/*.log {
        daily
        missingok
        rotate 1
        compress
        notifempty
        copytruncate
        su ubuntu ubuntu
      }
      EOF
      sudo logrotate /etc/logrotate.d/#{Rails.application.class.module_parent_name.downcase}
    MSG
    file.close
    system("chmod +x #{filepath}")
    puts "END - Create startup.sh for #{args[:env]}"
  end

  desc 'Create deploy.sh'
  task :create_deploy_sh, [:env, :aws_profile] => :environment do |task, args|
    puts "START - Create deploy.sh for #{args[:env]}"
    filepath = Rails.root.join('terraform', args[:env], 'deploy.sh')
    file = File.open(filepath, 'w')
    file.puts <<~MSG
      #!/usr/bin/env bash

      SCRIPT_PATH=$(dirname `which $0`)

      cp $SCRIPT_PATH/../../config/master.key $SCRIPT_PATH/master.key
      cp $HOME/.aws/credentials $SCRIPT_PATH/awscredentials

      docker build \
        -t \
        #{Rails.application.class.module_parent_name.downcase}-#{args[:env]}:latest \
        $SCRIPT_PATH

      echo 'terraform init'
      docker run \
        -it \
        --rm \
        --env AWS_SHARED_CREDENTIALS_FILE=awscredentials \
        --env AWS_PROFILE=#{args[:aws_profile]} \
        -v $SCRIPT_PATH:/workspace \
        #{Rails.application.class.module_parent_name.downcase}-#{args[:env]} \
        init

      echo 'terraform apply'
      docker run \
        -it \
        --rm \
        --env TF_LOG=ERROR \
        --env TF_LOG_PATH=tf_log \
        --env AWS_SHARED_CREDENTIALS_FILE=awscredentials \
        --env AWS_PROFILE=#{args[:aws_profile]} \
        -v $SCRIPT_PATH:/workspace \
        #{Rails.application.class.module_parent_name.downcase}-#{args[:env]} \
        apply

      rm $SCRIPT_PATH/master.key
      rm $SCRIPT_PATH/awscredentials
    MSG
    system("chmod +x #{filepath}")
    file.close
    puts "END - Create deploy.sh for #{args[:env]}"
  end

  desc 'Create destroy.sh'
  task :create_destroy_sh, [:env, :aws_profile] => :environment do |task, args|
    puts "START - Create destroy.sh for #{args[:env]}"
    filepath = Rails.root.join('terraform', args[:env], 'destroy.sh')
    file = File.open(filepath, 'w')
    file.puts <<~MSG
      #!/usr/bin/env bash

      SCRIPT_PATH=$(dirname `which $0`)

      cp $HOME/.aws/credentials $SCRIPT_PATH/awscredentials

      docker run \
        -it \
        --rm \
        --env AWS_SHARED_CREDENTIALS_FILE=awscredentials \
        --env AWS_PROFILE=#{args[:aws_profile]} \
        -v $SCRIPT_PATH:/workspace \
        #{Rails.application.class.module_parent_name.downcase}-#{args[:env]} \
        destroy

      rm $SCRIPT_PATH/awscredentials

    MSG
    file.close
    system("chmod +x #{filepath}")
    puts "END - Create destroy.sh for #{args[:env]}"
  end

  desc 'Create the terraform files'
  task init: :environment do
    env = aws_profile = region = ''
    loop do
      puts 'Enter environment:'
      env = STDIN.gets.chomp

      break unless env.blank?

      puts 'Nothing entered. Please enter an environment (eg staging, uat)'
    end

    loop do
      puts 'Enter region:'
      region = STDIN.gets.chomp

      break unless region.blank?

      puts 'Nothing entered. Please enter an region (eg us-east-1)'
    end

    loop do
      puts 'Enter your desired aws profile for this project:'
      aws_profile = STDIN.gets.chomp

      break unless aws_profile.blank?

      puts 'Nothing entered. Please enter your desired aws profile for this project.'
    end

    Rake::Task['terraform:checks'].invoke(env, aws_profile, region)
    Rake::Task['terraform:create_tfstate_bucket'].invoke(env, aws_profile, region)
    Rake::Task['terraform:create_env_folders'].invoke(env)
    Rake::Task['terraform:generate_ssh_keys'].invoke(env)
    Rake::Task['terraform:copy_template_files'].invoke(env)
    Rake::Task['terraform:create_variables_tf'].invoke(env, region)
    Rake::Task['terraform:create_setup_tf'].invoke(env, region)
    Rake::Task['terraform:create_push_error_state_sh'].invoke(env, aws_profile)
    Rake::Task['terraform:create_startup_sh'].invoke(env, aws_profile)
    Rake::Task['terraform:create_deploy_sh'].invoke(env, aws_profile)
    Rake::Task['terraform:create_destroy_sh'].invoke(env, aws_profile)
    Rake::Task['terraform:create_destroy_sh'].invoke(env, aws_profile)

    puts ''
    puts 'Terraform files created!'
    puts "Make sure you have your config/environments/#{region}.rb file setup!"
    puts "Make sure you have your config/deploy.rb file setup for deploying via mina on #{env} too!"
    puts "Run `source #{Rails.root.join('terraform', env, 'deploy.sh')}` to deploy your infrastructure now!"
  end
end

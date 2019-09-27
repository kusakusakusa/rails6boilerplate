# frozen_string_literal: true

PROJECT_NAME=Rails.application.class.module_parent_name.downcase

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
    private_key_file_name = "#{PROJECT_NAME}-#{args[:env]}"
    filepath = "#{Rails.root.join('terraform', args[:env], 'ssh_keys')}/#{private_key_file_name}"
    puts "START - Create private/public keys for #{args[:env]}"

    if File.exist? filepath
      puts 'Private key already created'
    else
      `ssh-keygen -t rsa -f #{filepath} -C #{private_key_file_name} -N ''`
      puts "chmod 400 private and public keys for #{args[:env]}"
      `chmod 400 #{filepath}`
      `chmod 400 #{filepath}.pub`
    end

    puts "END - Create private/public keys for #{args[:env]}"
  end

  desc 'Copy template files'
  task :copy_template_files, [:env] => :environment do |task, args|
    puts "START - Copy files in `templates/non_production` folder into #{args[:env]} folder in terraform"
    FileUtils.cp_r "#{Rails.root.join('terraform', 'templates', 'non_production')}/.", Rails.root.join('terraform', args[:env])
    puts "END - Copy files in `templates/non_production` folder into #{args[:env]} folder in terraform"
  end

  desc 'Create tfstate_bucket'
  task :create_tfstate_bucket, [:env, :aws_profile, :region] => :environment do |task, args|
    # create terraform backend s3 bucket via aws-cli
    # aws-cli is assumed to be present on local machine

    tfstate_bucket_name = "#{PROJECT_NAME}-#{args[:env]}-tfstate"
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
      }

      terraform {
        required_version = "~> 0.12.0"
        backend "s3" {
          bucket = "#{PROJECT_NAME}-#{args[:env]}-tfstate"
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
        default = "#{PROJECT_NAME}"
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

  desc 'Create logrotate.sh'
  task :create_logrotate_sh, [:env] => :environment do |task, args|
    puts "START - Create create_logrotate.sh for #{args[:env]}"
    filepath = Rails.root.join('terraform', args[:env], 'packer_scripts', 'logrotate.sh')
    file = File.open(filepath, 'w')
    file.puts <<~MSG
      #!/usr/bin/env bash

      echo 'Setup logrotate'
      sudo touch /etc/logrotate.d/#{PROJECT_NAME}
      sudo tee /etc/logrotate.d/#{PROJECT_NAME} > /dev/null <<EOF
      /home/ubuntu/#{PROJECT_NAME}/shared/log/*.log {
        daily
        missingok
        rotate 1
        compress
        notifempty
        copytruncate
        su ubuntu ubuntu
      }
      EOF
      sudo logrotate /etc/logrotate.d/#{PROJECT_NAME}
    MSG
    file.close
    puts "END - Create logrotate.sh for #{args[:env]}"
  end

  desc 'Create mysql_installation.sh'
  task :create_mysql_installation_sh, [:env] => :environment do |task, args|
    puts "START - Create mysql_installation.sh for #{args[:env]}"
    db_password = Rails.application.credentials.dig(args[:env].to_sym, :database, :password)
    filepath = Rails.root.join('terraform', args[:env], 'packer_scripts', 'mysql_installation.sh')
    file = File.open(filepath, 'w')
    file.puts <<~MSG
      #!/usr/bin/env bash

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
    MSG
    file.close
    puts "END - Create mysql_installation.sh for #{args[:env]}"
  end

  desc 'Create startup.sh'
  task :create_startup_sh, [:env, :aws_profile] => :environment do |task, args|
    puts "START - Create startup.sh for #{args[:env]}"
    filepath = Rails.root.join('terraform', args[:env], 'scripts', 'startup.sh')
    file = File.open(filepath, 'w')
    file.puts <<~MSG
      #!/usr/bin/env bash

      # copy keys files
      aws s3 cp s3://#{PROJECT_NAME}-#{args[:env]}-secrets/#{PROJECT_NAME}-#{args[:env]} /home/ubuntu/.ssh/id_rsa
      if [ $? -eq 0 ]
      then
        echo 'Successfully copied private key'
      else
        echo 'Fail to copy private key'
        exit 1
      fi

      aws s3 cp s3://#{PROJECT_NAME}-#{args[:env]}-secrets/#{PROJECT_NAME}-#{args[:env]}.pub /home/ubuntu/.ssh/id_rsa.pub
      if [ $? -eq 0 ]
      then
        echo 'Successfully copied public key'
      else
        echo 'Fail to copy public key'
        exit 1
      fi
      chmod 400 /home/ubuntu/.ssh/id_rsa
      chmod 400 /home/ubuntu/.ssh/id_rsa.pub
    MSG
    file.close
    system("chmod +x #{filepath}")
    puts "END - Create startup.sh for #{args[:env]}"
  end

  desc 'Create app.sh'
  task :create_app_sh, [:env, :aws_profile] => :environment do |task, args|
    puts "START - Create app.sh for #{args[:env]}"
    filepath = Rails.root.join('terraform', args[:env], 'scripts/' 'app.sh')
    file = File.open(filepath, 'w')
    file.puts <<~MSG
      #!/usr/bin/env bash

      echo 'Overwrite nginx default available site'
      sudo chgrp $(whoami) /etc/nginx/sites-available/default
      sudo chown $(whoami) /etc/nginx/sites-available/default
      sudo chmod +w /etc/nginx/sites-available/default
      cat > /etc/nginx/sites-available/default <<EOF
      upstream backend {
        server unix:///home/ubuntu/#{PROJECT_NAME}/shared/tmp/sockets/puma.sock fail_timeout=0;
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
          root /home/ubuntu/#{PROJECT_NAME}/current/public;
          expires max;
          add_header Cache-Control public;
          gzip_static on;
          #add_header ETag "";
          break;
        }
      }
      EOF
    MSG
    file.close
    puts "END - Create app.sh for #{args[:env]}"
  end

  desc 'Create deploy.sh'
  task :create_deploy_sh, [:env, :aws_profile] => :environment do |task, args|
    puts "START - Create deploy.sh for #{args[:env]}"
    packer_image_name = "#{PROJECT_NAME}-#{args[:env]}-packer"
    terraform_image_name = "#{PROJECT_NAME}-#{args[:env]}-terraform"
    filepath = Rails.root.join('terraform', args[:env], 'deploy.sh')
    file = File.open(filepath, 'w')
    file.puts <<~MSG
      #!/usr/bin/env bash

      SCRIPT_PATH=$(dirname `which $0`)

      cp $SCRIPT_PATH/../../config/master.key $SCRIPT_PATH/master.key

      aws_access_key_id=$(aws configure get aws_access_key_id --profile #{args[:aws_profile]})
      aws_secret_access_key=$(aws configure get aws_secret_access_key --profile #{args[:aws_profile]})

      trap 'rm $SCRIPT_PATH/master.key' EXIT

      echo 'docker build target packer'
      docker build \
        -t #{packer_image_name}:latest \
        --target packer \
        --build-arg AWS_ACCESS_KEY_ID_BUILD_ARG=$aws_access_key_id \
        --build-arg AWS_SECRET_ACCESS_KEY_BUILD_ARG=$aws_secret_access_key \
        $SCRIPT_PATH

      echo 'packer build ec2 instance AMI for #{args[:env]}'
      docker run \
        -it \
        --rm \
        --env AWS_ACCESS_KEY_ID=$aws_access_key_id \
        --env AWS_SECRET_ACCESS_KEY=$aws_secret_access_key \
        #{packer_image_name} \
        build ec2.json

      echo 'docker build target terraform'
      docker build \
        -t #{terraform_image_name}:latest \
        --target terraform \
        --build-arg AWS_ACCESS_KEY_ID_BUILD_ARG=$aws_access_key_id \
        --build-arg AWS_SECRET_ACCESS_KEY_BUILD_ARG=$aws_secret_access_key \
        $SCRIPT_PATH

      echo 'terraform init'
      docker run \
        -it \
        --rm \
        --env AWS_ACCESS_KEY_ID=$aws_access_key_id \
        --env AWS_SECRET_ACCESS_KEY=$aws_secret_access_key \
        -v $SCRIPT_PATH/master.key:/workspace/master.key \
        #{terraform_image_name} \
        init

      echo 'terraform apply'
      docker run \
        -it \
        --rm \
        --env TF_LOG=ERROR \
        --env TF_LOG_PATH=tf_log \
        --env AWS_ACCESS_KEY_ID=$aws_access_key_id \
        --env AWS_SECRET_ACCESS_KEY=$aws_secret_access_key \
        -v $SCRIPT_PATH/error.tfstate:/workspace/error.tfstate \
        -v $SCRIPT_PATH/master.key:/workspace/master.key \
        -v $SCRIPT_PATH/ssh_keys:/workspace/ssh_keys \
        -v $SCRIPT_PATH/tf_log:/workspace/tf_log \
        #{terraform_image_name} \
        apply
    MSG
    system("chmod +x #{filepath}")
    file.close
    puts "END - Create deploy.sh for #{args[:env]}"
  end

  # for pushing terraform errored.tfstate in the event of
  # losing internet connection during deployment
  # with a remote backend
  desc 'Create push_error_state.sh'
  task :create_push_error_state_sh, [:env, :aws_profile] => :environment do |task, args|
    puts "START - Create push_error_state.sh for #{args[:env]}"
    terraform_image_name = "#{PROJECT_NAME}-#{args[:env]}-terraform"
    filepath = Rails.root.join('terraform', args[:env], 'push_error_state.sh')
    file = File.open(filepath, 'w')
    file.puts <<~MSG
      #!/usr/bin/env bash

      SCRIPT_PATH=$(dirname `which $0`)

      echo $SCRIPT_PATH

      cp $SCRIPT_PATH/../../config/master.key $SCRIPT_PATH/master.key

      aws_access_key_id=$(aws configure get aws_access_key_id --profile #{args[:aws_profile]})
      aws_secret_access_key=$(aws configure get aws_secret_access_key --profile #{args[:aws_profile]})

      trap 'rm $SCRIPT_PATH/master.key' EXIT

      echo 'terraform push error.tfstate'
      docker run \
        -it \
        --rm \
        --env AWS_ACCESS_KEY_ID=$aws_access_key_id \
        --env AWS_SECRET_ACCESS_KEY=$aws_secret_access_key \
        -v $SCRIPT_PATH/error.tfstate:/workspace/error.tfstate \
        -v $SCRIPT_PATH/master.key:/workspace/master.key \
        -v $SCRIPT_PATH/tf_log:/workspace/tf_log \
        #{terraform_image_name} \
        state push errored.tfstate
    MSG
    file.close
    system("chmod +x #{filepath}")
    puts "END - Create push_error_state.sh for #{args[:env]}"
  end

  desc 'Create destroy.sh'
  task :create_destroy_sh, [:env, :aws_profile] => :environment do |task, args|
    puts "START - Create destroy.sh for #{args[:env]}"
    terraform_image_name = "#{PROJECT_NAME}-#{args[:env]}-terraform"
    filepath = Rails.root.join('terraform', args[:env], 'destroy.sh')
    file = File.open(filepath, 'w')
    file.puts <<~MSG
      #!/usr/bin/env bash

      SCRIPT_PATH=$(dirname `which $0`)

      cp $SCRIPT_PATH/../../config/master.key $SCRIPT_PATH/master.key

      aws_access_key_id=$(aws configure get aws_access_key_id --profile #{args[:aws_profile]})
      aws_secret_access_key=$(aws configure get aws_secret_access_key --profile #{args[:aws_profile]})

      trap 'rm $SCRIPT_PATH/master.key' EXIT

      docker run \
        -it \
        --rm \
        --env AWS_ACCESS_KEY_ID=$aws_access_key_id \
        --env AWS_SECRET_ACCESS_KEY=$aws_secret_access_key \
        -v $SCRIPT_PATH/error.tfstate:/workspace/error.tfstate \
        -v $SCRIPT_PATH/master.key:/workspace/master.key \
        -v $SCRIPT_PATH/tf_log:/workspace/tf_log \
        -v $SCRIPT_PATH/ssh_keys:/workspace/ssh_keys \
        #{terraform_image_name} \
        destroy

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
    Rake::Task['packer:create_ec2_json'].invoke(aws_profile, env, region)
    Rake::Task['terraform:create_push_error_state_sh'].invoke(env, aws_profile)
    Rake::Task['terraform:create_logrotate_sh'].invoke(env)
    Rake::Task['terraform:create_mysql_installation_sh'].invoke(env)
    Rake::Task['terraform:create_startup_sh'].invoke(env, aws_profile)
    Rake::Task['terraform:create_app_sh'].invoke(env, aws_profile)
    Rake::Task['terraform:create_deploy_sh'].invoke(env, aws_profile)
    Rake::Task['terraform:create_destroy_sh'].invoke(env, aws_profile)
    Rake::Task['terraform:create_destroy_sh'].invoke(env, aws_profile)

    puts ''
    puts 'Terraform files created!'
    puts "Make sure you have your config/environments/#{env}.rb file setup!"
    puts "Make sure you have your config/deploy.rb file setup for deploying via mina on #{env} too!"
    puts "Run `rake terraform:deploy` to deploy your infrastructure now!"
  end

  desc 'Deploy resources'
  task deploy: :environment do
    env = ''
    loop do
      puts 'Enter environment:'
      env = STDIN.gets.chomp

      break unless env.blank?

      puts 'Nothing entered. Please enter an environment (eg staging, uat)'
    end
    system("sh #{Rails.root.join('terraform', 'staging', 'deploy.sh').to_s}")
  end

  desc 'Destroy resources'
  task destroy: :environment do
    env = ''
    loop do
      puts 'Enter environment:'
      env = STDIN.gets.chomp

      break unless env.blank?

      puts 'Nothing entered. Please enter an environment (eg staging, uat)'
    end
    system("sh #{Rails.root.join('terraform', env, 'destroy.sh').to_s}")
  end
end

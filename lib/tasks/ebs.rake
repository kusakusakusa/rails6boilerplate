# frozen_string_literal: true

module Ebs
  class Helper
    def self.is_single_instance
      is_single = nil
      loop do
        puts 'Are you deploying a single instance? (y|n)'
        is_single = STDIN.gets.chomp.downcase

        break if %w[y n].include?(is_single)

        puts 'Enter either y or n:'
      end

      is_single == 'y'
    end

    def self.inputs(args = nil)
      env = aws_profile = region = ''

      if args.nil? ||
         (
          args[:env].blank? &&
          args[:aws_profile].blank? &&
          args[:region].blank?
        )

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
      else
        env = args[:env]
        aws_profile = args[:aws_profile]
        region = args[:region]
      end

      [env, aws_profile, region]
    end

    def self.announce(msg)
      puts ''
      msg.length.times { print '¥' }
      puts ''
      puts msg
      msg.length.times { print '¥' }
      puts ''
      puts ''
    end

    def self.bastion(ec2_client:, env:)
      results = ec2_client.describe_instances(
        filters: [
          {
            name: 'instance.group-name',
            values: ["#{PROJECT_NAME}#{env}-bastion"]
          }
        ]
      )

      abort('There are more than 1 reservations. Please check!') if results.reservations.count > 1

      abort("There are no reservations. Make sure to setup your bastion servers first by running the command below:\n\n\trake ebs:bastion:up\n\n") if results.reservations.count.zero?

      instances = results.reservations.first.instances

      abort("There are more than 1 bastion servers.\nThis should not happen. Please check!") if instances.count > 1

      instances.first
    end

    def self.ec2_client(aws_profile:, region:)
      aws_access_key_id = `aws --profile #{aws_profile} configure get aws_access_key_id`.chomp
      aws_secret_access_key = `aws --profile #{aws_profile} configure get aws_secret_access_key`.chomp
      Aws::EC2::Client.new(
        region: region,
        access_key_id: aws_access_key_id,
        secret_access_key: aws_secret_access_key
      )
    end

    def self.s3_client(aws_profile:, region:)
      aws_access_key_id = `aws --profile #{aws_profile} configure get aws_access_key_id`.chomp
      aws_secret_access_key = `aws --profile #{aws_profile} configure get aws_secret_access_key`.chomp
      Aws::S3::Client.new(
        region: region,
        access_key_id: aws_access_key_id,
        secret_access_key: aws_secret_access_key
      )
    end

    def self.rds_client(aws_profile:, region:)
      aws_access_key_id = `aws --profile #{aws_profile} configure get aws_access_key_id`.chomp
      aws_secret_access_key = `aws --profile #{aws_profile} configure get aws_secret_access_key`.chomp
      Aws::RDS::Client.new(
        region: region,
        access_key_id: aws_access_key_id,
        secret_access_key: aws_secret_access_key
      )
    end

    def self.tunnel(env:, aws_profile:, region:)
      ec2_client = Ebs::Helper.ec2_client(
        aws_profile: aws_profile,
        region: region
      )

      bastion = Ebs::Helper.bastion(
        ec2_client: ec2_client,
        env: env
      )

      ##### Get rds #####
      rds_client = Ebs::Helper.rds_client(
        aws_profile: aws_profile,
        region: region
      )
      result = rds_client.describe_db_instances(
        db_instance_identifier: "rds-#{PROJECT_NAME}#{env}"
      )
      abort("More than 1 db instances found.\nThis should not happen. Please check!\n") if result.db_instances.count > 1
      db_instance = result.db_instances.first

      forwarded_port_no = rand(10_000..60_000)
      puts "\n  Tunneled port: #{forwarded_port_no}\n\n"

      gateway = Net::SSH::Gateway.new(
        bastion.public_ip_address,
        'ec2-user',
        keys: [Rails.root.join('terraform', env, PROJECT_NAME)]
      )
      abort("\nGateway not active!\n") unless gateway.active?
      port = gateway.open(
        db_instance.endpoint.address,
        db_instance.endpoint.port,
        forwarded_port_no
      )

      yield forwarded_port_no

      gateway.close(port)
    end
  end
end

namespace :ebs do
  PROJECT_NAME = Rails.application.class.module_parent_name.underscore

  ####################
  ### Common Tasks ###
  ####################
  desc 'Checks before proceeding'
  task :checks, %i[
    env
    aws_profile
    region
  ] => :environment do |_, args|
    env = args[:env]
    aws_profile = args[:aws_profile]
    region = args[:region]

    Ebs::Helper.announce 'START - Checks necessary conditions before proceeding'
    abort('awscli not installed!') if `type -a aws`.blank?
    abort('~/.aws/credentials does not exist!') unless File.exist?("#{ENV['HOME']}/.aws/credentials")
    abort("#{aws_profile} does not have aws_access_key_id properly setup!") if `aws --profile #{aws_profile} configure get aws_access_key_id`.chomp.blank?
    abort("#{aws_profile} does not have aws_secret_access_key properly setup!") if `aws --profile #{aws_profile} configure get aws_secret_access_key`.chomp.blank?
    abort("Opt-in region #{region} are not supported!") if %w[
      me-south-1
      ap-east-1
    ].include? region
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
    ].include? region
    abort("No database password in credentials file for #{env} environment") unless Rails.application.credentials.dig(env.to_sym, :database, :password)
    Ebs::Helper.announce 'END - Checks necessary conditions before proceeding'
  end

  desc 'Generate private/public key'
  task :generate_ssh_keys, [:env] => :environment do |_, args|
    env = args[:env]

    # these keys will be used for:
    # 1. generating aws keypair
    # 2. authentication key for private git repository
    filepath = "#{Rails.root}/terraform/#{env}/#{PROJECT_NAME}"
    Ebs::Helper.announce "START - Create private/public keys for #{env}"

    if File.exist? filepath
      puts 'Private key already created'
    else
      `ssh-keygen -t rsa -f #{filepath} -C #{PROJECT_NAME} -N ''`
      puts "chmod 400 private and public keys for #{env}"
      `chmod 400 #{filepath}`
      `chmod 400 #{filepath}.pub`
    end

    Ebs::Helper.announce "END - Create private/public keys for #{env}"
  end

  #######################
  ### Terraform Files ###
  #######################
  namespace :terraform do
    desc 'Create tfstate_bucket'
    task :create_tfstate_bucket, %i[
      env
      aws_profile
      region
    ] => :environment do |_, args|
      env, aws_profile, region = Ebs::Helper.inputs(args)

      # create terraform backend s3 bucket via aws-cli
      # aws-cli is assumed to be present on local machine

      tfstate_bucket_name = "#{PROJECT_NAME}-#{env}-tfstate"
      tfstate_bucket = `aws s3 --profile #{aws_profile} ls | grep " #{tfstate_bucket_name}$"`.chomp
      if tfstate_bucket.blank?
        Ebs::Helper.announce "Creating Terraform state bucket (#{tfstate_bucket_name})"

        s3_client = Ebs::Helper.s3_client(
          aws_profile: aws_profile,
          region: region
        )
        
        # conditional configuration for location_constraint
        options = {
          bucket: tfstate_bucket_name
        }
        unless region == 'us-east-1'
          options[:create_bucket_configuration] = {}
          options[:create_bucket_configuration][:location_constraint] = region
        end
        s3_client.create_bucket(options)
      else
        Ebs::Helper.announce "Terraform state bucket (#{tfstate_bucket_name}) already created!"
      end

      puts "Enabling/overwriting versioning for #{tfstate_bucket_name}"

      s3_client = Ebs::Helper.s3_client(
        aws_profile: aws_profile,
        region: region
      )

      s3_client.put_bucket_versioning({
        bucket: tfstate_bucket_name,
        versioning_configuration: {
          status: "Enabled", 
        }, 
      })

      s3_client.put_bucket_encryption({
        bucket: tfstate_bucket_name,
        server_side_encryption_configuration: {
          rules: [
            {
              apply_server_side_encryption_by_default: {
                sse_algorithm: "AES256",
              },
            },
          ],
        },
      })

      puts "Enabling/overwriting lifecycle for #{tfstate_bucket_name}"

      s3_client.put_bucket_lifecycle_configuration({
        bucket: tfstate_bucket_name, 
        lifecycle_configuration: {
          rules: [
            {
              id: "Remove non current version tfstate files", 
              status: "Enabled",
              prefix: "",
              noncurrent_version_expiration: {
                noncurrent_days: 30,
              },
            }, 
          ], 
        }, 
      })

      Ebs::Helper.announce 'Completed tfstate bucket configurations setup!'
    end

    desc 'Init Terraform'
    task :init, %i[
      env
      aws_profile
      region
    ] => :environment do |_, args|
      env, aws_profile, region = Ebs::Helper.inputs(args)
      Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

      db_name = Rails.application.credentials.dig(env.to_sym, :database, :db)
      db_username = Rails.application.credentials.dig(env.to_sym, :database, :username)
      db_password = Rails.application.credentials.dig(env.to_sym, :database, :password)

      sh "cd #{Rails.root.join('terraform', env)} && \
        docker run \
        --rm \
        --env AWS_ACCESS_KEY_ID=#{`aws --profile #{aws_profile} configure get aws_access_key_id`.chomp} \
        --env AWS_SECRET_ACCESS_KEY=#{`aws --profile #{aws_profile} configure get aws_secret_access_key`.chomp} \
        --env AWS_DEFAULT_REGION=#{region} \
        -v #{Rails.root.join('terraform', env)}:/workspace \
        -v #{Rails.root.join('terraform', 'modules')}:/workspace/modules \
        -w /workspace \
        -it \
        hashicorp/terraform:0.13.0 \
        init \
        -var='project_name=#{PROJECT_NAME}' \
        -var='master_key=#{`cat #{Rails.root.join('config', 'master.key')}`}' \
        -var='region=#{region}' \
        -var='env=#{env}' \
        -var='db_username=#{db_username}' \
        -var='db_password=#{db_password}' \
        -var='db_name=#{db_name}'"
    end

    desc 'Apply Terraform'
    task :apply, %i[
      env
      aws_profile
      region
      auto_approve
    ] => :environment do |_, args|
      env, aws_profile, region = Ebs::Helper.inputs(args)
      Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

      db_name = Rails.application.credentials.dig(env.to_sym, :database, :db)
      db_username = Rails.application.credentials.dig(env.to_sym, :database, :username)
      db_password = Rails.application.credentials.dig(env.to_sym, :database, :password)

      sh "cd #{Rails.root.join('terraform', env)} && \
        docker run \
        --rm \
        --env AWS_ACCESS_KEY_ID=#{`aws --profile #{aws_profile} configure get aws_access_key_id`.chomp} \
        --env AWS_SECRET_ACCESS_KEY=#{`aws --profile #{aws_profile} configure get aws_secret_access_key`.chomp} \
        --env AWS_DEFAULT_REGION=#{region} \
        -v #{Rails.root.join('terraform', env)}:/workspace \
        -v #{Rails.root.join('terraform', 'modules')}:/workspace/modules \
        -w /workspace \
        -it \
        hashicorp/terraform:0.13.0 \
        apply #{auto_approve = args[:auto_approve] ? '-auto-approve' : ''} \
        -var='project_name=#{PROJECT_NAME}' \
        -var='master_key=#{`cat #{Rails.root.join('config', 'master.key')}`}' \
        -var='region=#{region}' \
        -var='env=#{env}' \
        -var='db_username=#{db_username}' \
        -var='db_password=#{db_password}' \
        -var='db_name=#{db_name}'"
    end
  end

  #####################
  ### Bastion Tasks ###
  #####################
  namespace :bastion do
    desc 'Unpack bastion server AMI'
    task :unpack, %i[
      env
      aws_profile
      region
    ] => :environment do |_, args|
      env, aws_profile, region = Ebs::Helper.inputs(args)
      Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

      Ebs::Helper.announce 'START - Unpacking bastion AMI...'

      ec2_client = Ebs::Helper.ec2_client(
        aws_profile: aws_profile,
        region: region
      )

      ami = ec2_client.describe_images(
        filters: [
          {
            name: 'name',
            values: ["bastion-#{PROJECT_NAME}-#{env}"]
          }
        ],
        owners: ['self']
      ).images.max_by(&:creation_date) # latest image

      if ami.nil?
        puts "No bastion image found!\n"
      else
        ec2_client.deregister_image(
          image_id: ami.image_id
        )
      end

      Ebs::Helper.announce 'END - Unpacked bastion AMI'
    end

    desc 'Setup bastion server'
    task up: :environment do
      env, aws_profile, region = Ebs::Helper.inputs
      Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

      Ebs::Helper.announce 'START - Setting up bastion...'

      Rake::Task['ebs:bastion:pack'].invoke(env, aws_profile, region)

      unless File.exist?(Rails.root.join('terraform', env, 'bastion.tf'))
        file = File.open(Rails.root.join('terraform', env, 'bastion.tf'), 'w')
        file.puts <<~MSG
          module "bastion" {
            source = "./modules/bastion"

            project_name = var.project_name
            env = var.env
            aws_subnet = module.multiple_instances.aws_subnet
            aws_security_group = module.multiple_instances.aws_security_group
            aws_key_pair = module.common.aws_key_pair
          }
        MSG
        file.close
      end

      Rake::Task['ebs:terraform:init'].invoke(env, aws_profile, region)

      Rake::Task['ebs:terraform:apply'].invoke(env, aws_profile, region, true)

      Ebs::Helper.announce 'END - Set up bastion!'
    end

    desc 'Shutdown bastion server'
    task down: :environment do
      env, aws_profile, region = Ebs::Helper.inputs
      Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

      Ebs::Helper.announce 'START - Shutting up bastion...'

      if File.exist?(Rails.root.join('terraform', env, 'bastion.tf'))

        FileUtils.rm(Rails.root.join('terraform', env, 'bastion.tf'))

        Rake::Task['ebs:terraform:init'].invoke(env, aws_profile, region)

        Rake::Task['ebs:terraform:apply'].invoke(env, aws_profile, region, true)
      else
        abort("`bastion.tf` file not found!\nDo nothing here!\n")
      end

      Ebs::Helper.announce 'END - Shutdown bastion!'
    end

    desc 'Pack bastion server AMI'
    task :pack, %i[
      env
      aws_profile
      region
    ] => :environment do |_, args|
      env, aws_profile, region = Ebs::Helper.inputs(args)

      Ebs::Helper.announce 'START - Packing bastion...'

      begin
        sh "cd #{Rails.root.join('terraform', env)} && \
          docker run \
          -it \
          --rm \
          --env AWS_ACCESS_KEY_ID=#{`aws --profile #{aws_profile} configure get aws_access_key_id`.chomp} \
          --env AWS_SECRET_ACCESS_KEY=#{`aws --profile #{aws_profile} configure get aws_secret_access_key`.chomp} \
          --env AWS_DEFAULT_REGION=#{region} \
          -v #{Rails.root.join('terraform', 'bastion.json')}:/workspace/bastion.json \
          -w /workspace \
          hashicorp/packer:light \
          build \
          -var 'project_name=#{PROJECT_NAME}' \
          -var 'region=#{region}' \
          -var 'env=#{env}' \
          bastion.json"

        Ebs::Helper.announce 'END - Packed bastion AMI!'
      rescue RuntimeError => e
        # binding.pry
        Ebs::Helper.announce 'END - Bastion AMI already created!'
      rescue => e
        binding.pry
      end
    end

    desc 'SSH into private servers via bastion'
    task ssh: :environment do
      env, aws_profile, region = Ebs::Helper.inputs
      Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

      Ebs::Helper.announce 'START - ssh into bastion...'

      ec2_client = Ebs::Helper.ec2_client(
        aws_profile: aws_profile,
        region: region
      )

      ##### Get bastion #####
      bastion = Ebs::Helper.bastion(
        ec2_client: ec2_client,
        env: env
      )

      ##### Get one of the instances #####
      results = ec2_client.describe_instances(
        filters: [
          {
            name: 'instance.group-name',
            values: ["#{PROJECT_NAME}#{env}-web-servers"]
          }
        ]
      )

      abort("There are no reservations. Make sure to setup the ebs instance first by running the comand:\n\n\trake ebs:init\n") if results.reservations.count.zero?

      private_ip_addresses = results.reservations.map do |reservation|
        reservation.instances.map(&:private_ip_address)
      end.flatten

      abort("There are no private_ip_addresses.\nThis should not happen. Please check!") if private_ip_addresses.count.zero?

      ##### SSH time #####
      # TODO ask for private ip address choice
      # TODO check local machine has ssh agent

      puts 'Clear ssh agent identities'
      sh 'ssh-add -D'
      puts 'Add keypair to ssh agent'
      sh "ssh-add -K #{Rails.root.join('terraform', env, "#{PROJECT_NAME}")}"
      puts "ssh into bastion then into private instance (#{private_ip_addresses.first})"
      sh('ssh ' \
      '-tt ' \
      '-A ' \
      "-i #{Rails.root.join('terraform', env, "#{PROJECT_NAME}")} " \
      "ec2-user@#{bastion.public_ip_address} " \
      "-o 'UserKnownHostsFile /dev/null' " \
      '-o StrictHostKeyChecking=no ' \
      "\"ssh ec2-user@#{private_ip_addresses.first} " \
      "-o 'UserKnownHostsFile /dev/null' " \
      '-o StrictHostKeyChecking=no"')
      puts 'Clear ssh agent identities'
      sh 'ssh-add -D'

      Ebs::Helper.announce 'END - ssh-ed into bastion!'
    end
  end

  ###################
  ### Rails Tasks ###
  ###################
  namespace :rails do
    desc 'For running rails console via bastion'
    task console: :environment do
      env, aws_profile, region = Ebs::Helper.inputs
      Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

      Ebs::Helper.announce 'START - Running rails console via tunneling through bastion'

      Ebs::Helper.tunnel(
        env: env,
        aws_profile: aws_profile,
        region: region
      ) do |forwarded_port_no|
        dbname = Rails.application.credentials.dig(env.to_sym, :database, :db)
        username = Rails.application.credentials.dig(env.to_sym, :database, :username)
        password = Rails.application.credentials.dig(env.to_sym, :database, :password)

        sh "DATABASE_URL=mysql2://#{username}:#{password}@127.0.0.1:#{forwarded_port_no}/#{dbname} RAILS_ENV=#{env} bundle exec rails console"
      end

      Ebs::Helper.announce 'END - Finished rails console!'
    end

    desc 'Seed database'
    task seed: :environment do
      env, aws_profile, region = Ebs::Helper.inputs
      Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

      Ebs::Helper.announce "START - Seeding #{env} database"

      Ebs::Helper.tunnel(
        env: env,
        aws_profile: aws_profile,
        region: region
      ) do |forwarded_port_no|
        dbname = Rails.application.credentials.dig(env.to_sym, :database, :db)
        username = Rails.application.credentials.dig(env.to_sym, :database, :username)
        password = Rails.application.credentials.dig(env.to_sym, :database, :password)

        sh "DATABASE_URL=mysql2://#{username}:#{password}@127.0.0.1:#{forwarded_port_no}/#{dbname} RAILS_ENV=#{env} bundle exec rails db:seed"
      end

      Ebs::Helper.announce "END - Seeded #{env} database!"
    end

    desc 'Drop, create, migrate and seed database'
    task reseed: :environment do
      env, aws_profile, region = Ebs::Helper.inputs
      is_single_instance = Ebs::Helper.is_single_instance
      Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

      Ebs::Helper.announce "RESEEDING #{env} database..."

      puts "You are reseeding the #{env.upcase} database for #{PROJECT_NAME}. Are you sure you want to proceed? (y for yes)"

      reply = STDIN.gets.chomp
      abort if reply.downcase != 'y'

      dbname = Rails.application.credentials.dig(env.to_sym, :database, :db)
      username = Rails.application.credentials.dig(env.to_sym, :database, :username)
      password = Rails.application.credentials.dig(env.to_sym, :database, :password)

      if is_single_instance
        ec2_client = Ebs::Helper.ec2_client(
          aws_profile: aws_profile,
          region: region
        )

        results = ec2_client.describe_instances(
          filters: [
            {
              name: 'instance.group-name',
              values: ["web_server-single_instance-#{PROJECT_NAME}#{env}"]
            }
          ]
        )

        abort('There are no reservations. The instance might be down. Please check.') if results.reservations.count.zero?

        public_ip_address = results.reservations.map do |reservation|
          reservation.instances.map(&:public_ip_address)
        end.flatten.first

        Net::SSH.start(
          public_ip_address,
          'ec2-user',
          keys: [Rails.root.join('terraform', env, PROJECT_NAME)]
        ) do |ssh|
          output = ssh.exec!('echo RAILS_ENV = $RAILS_ENV && echo DATABASE_URL = $DATABASE_URL')
          puts output

          # capture all stderr and stdout output from a remote process
          output = ssh.exec!('cd /var/app/current && rails db:drop')
          puts output

          output = ssh.exec!('cd /var/app/current && rails db:create')
          puts output

          output = ssh.exec!('cd /var/app/current && rails db:migrate')
          puts output

          output = ssh.exec!('cd /var/app/current && rails db:seed')
          puts output
        end
      else
        Ebs::Helper.tunnel(
          env: env,
          aws_profile: aws_profile,
          region: region
        ) do |forwarded_port_no|
          sh "DATABASE_URL=mysql2://#{username}:#{password}@127.0.0.1:#{forwarded_port_no}/#{dbname} DISABLE_DATABASE_ENVIRONMENT_CHECK=1 RAILS_ENV=#{env} bundle exec rails db:drop"
          sh "DATABASE_URL=mysql2://#{username}:#{password}@127.0.0.1:#{forwarded_port_no}/#{dbname} RAILS_ENV=#{env} bundle exec rails db:create"
          sh "DATABASE_URL=mysql2://#{username}:#{password}@127.0.0.1:#{forwarded_port_no}/#{dbname} RAILS_ENV=#{env} bundle exec rails db:migrate"
          sh "DATABASE_URL=mysql2://#{username}:#{password}@127.0.0.1:#{forwarded_port_no}/#{dbname} RAILS_ENV=#{env} bundle exec rails db:seed"
        end
      end

      Ebs::Helper.announce "END - Reseeded #{env} database!"
    end
  end

  ##################
  ### Main Tasks ###
  ##################
  desc 'For production-like env with proper infrastructure'
  task init: :environment do
    env, aws_profile, region = Ebs::Helper.inputs
    is_single_instance = Ebs::Helper.is_single_instance
    Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

    FileUtils.mkdir_p(Rails.root.join('terraform', env))
    Rake::Task['ebs:generate_ssh_keys'].invoke(env, aws_profile, region)
    Rake::Task['ebs:terraform:create_tfstate_bucket'].invoke(env, aws_profile, region)

    file = File.open(Rails.root.join('terraform', env, 'main.tf'), 'w')
    file.puts <<~MSG
      module "common" {
        source = "./modules/common"

        project_name = var.project_name
        env = var.env
        region = var.region
        public_key = file("./${var.project_name}.pub")
      }
    MSG

    if is_single_instance
      file.puts <<~MSG
        module "single_instance" {
          source = "./modules/single_instance"

          project_name = var.project_name
          env = var.env
          db_username = var.db_username
          db_password = var.db_password
          db_name = var.db_name
          master_key = var.master_key

          # resources
          aws_key_pair = module.common.aws_key_pair
        }

        output "endpoint_url" {
          value = module.single_instance.endpoint_url
        }

        output "rds-database-url" {
          value = module.single_instance.rds-database-url
        }
      MSG
    else
      file.puts <<~MSG
        module "multiple_instances" {
          source = "./modules/multiple_instances"

          project_name = var.project_name
          env = var.env
          db_username = var.db_username
          db_password = var.db_password
          db_name = var.db_name
          master_key = var.master_key

          # resources
          aws_key_pair = module.common.aws_key_pair
        }

        output "endpoint_url" {
          value = module.multiple_instances.endpoint_url
        }

        output "rds-database-url" {
          value = module.multiple_instances.rds-database-url
        }
      MSG
    end

    file.puts <<~MSG
      output "assets-user-access_key_id" {
        value = module.common.assets-user-access_key_id
      }

      output "assets-user-secret_access_key" {
        value = module.common.assets-user-secret_access_key
      }

      output "assets-bucket_name" {
        value = module.common.assets-bucket_name
      }

      output "cloudwatch-user-access_key_id" {
        value = module.common.cloudwatch-user-access_key_id
      }

      output "cloudwatch-user-secret_access_key" {
        value = module.common.cloudwatch-user-secret_access_key
      }
    MSG
    file.close

    file = File.open(Rails.root.join('terraform', env, 'variables.tf'), 'w')
    file.puts <<~MSG
      variable "project_name" {
        type = string
      }

      variable "region" {
        type = string
      }

      variable "env" {
        type = string
      }

      variable "db_username" {
        type = string
      }

      variable "db_password" {
        type = string
      }

      variable "db_name" {
        type = string
      }

      variable "master_key" {
        type = string
      }
    MSG
    file.close

    Rake::Task['ebs:apply'].invoke(env, aws_profile, region)

    Ebs::Helper.announce "Run this command to setup your production credentials for amazon_#{env} storage in your credentials file:\n\n\tEDITOR=vim rails credentials:edit\n\nRefer to `sample_credentials.yml` to see the structure.\n\nRun these commands next to deploy your application to the environment:\n\n\teb init --region #{region} --profile #{aws_profile}\n\teb deploy [--staged]\n\n"
  end

  desc 'For apply latest changes and getting outputs'
  task :apply, %i[
    env
    aws_profile
    region
  ] => :environment do |_, args|
    env, aws_profile, region = Ebs::Helper.inputs(args)

    FileUtils.mkdir_p(Rails.root.join('terraform', env))

    Rake::Task['ebs:terraform:init'].invoke(env, aws_profile, region)

    Rake::Task['ebs:terraform:apply'].invoke(env, aws_profile, region, false)
  end

  desc 'Output terraform values'
  task :output, %i[
    env
    aws_profile
    region
  ] => :environment do |_, args|
    env, aws_profile, region = Ebs::Helper.inputs(args)

    sh "cd #{Rails.root.join('terraform', env)} && \
      docker run \
      --rm \
      --env AWS_ACCESS_KEY_ID=#{`aws --profile #{aws_profile} configure get aws_access_key_id`.chomp} \
      --env AWS_SECRET_ACCESS_KEY=#{`aws --profile #{aws_profile} configure get aws_secret_access_key`.chomp} \
      --env AWS_DEFAULT_REGION=#{region} \
      -v #{Rails.root.join('terraform', env)}:/workspace \
      -v #{Rails.root.join('terraform', 'modules')}:/workspace/modules \
      -w /workspace \
      -it \
      hashicorp/terraform:0.13.0 \
      output"
  end

  desc 'For production-like env with proper infrastructure'
  task destroy: :environment do
    env, aws_profile, region = Ebs::Helper.inputs
    Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

    Ebs::Helper.announce 'START - Destroying infrastructure...'

    s3_client = Ebs::Helper.s3_client(
      aws_profile: aws_profile,
      region: region
    )

    if Dir.exist? Rails.root.join('terraform', env)
      #  empty asset bucket first 
      bucket_name = "#{PROJECT_NAME}-#{env}-assets"
      begin
        s3_client.head_bucket(bucket: bucket_name) # will check and throw error if bucket is not present

        result = s3_client.list_objects(bucket: bucket_name)
        if result.contents && !result.contents.empty?
          s3_client.delete_objects(
            bucket: bucket_name,
            delete: {
              objects: result.contents.map do |object|
                { key: object.key }
              end
            }
          )
        end
      rescue Aws::S3::Errors::NotFound
        Ebs::Helper.announce "#{bucket_name} already destroyed"
      end

      db_name = Rails.application.credentials.dig(env.to_sym, :database, :db)
      db_username = Rails.application.credentials.dig(env.to_sym, :database, :username)
      db_password = Rails.application.credentials.dig(env.to_sym, :database, :password)

      sh "cd #{Rails.root.join('terraform', env)} && \
      docker run \
      --rm \
      --env AWS_ACCESS_KEY_ID=#{`aws --profile #{aws_profile} configure get aws_access_key_id`.chomp} \
      --env AWS_SECRET_ACCESS_KEY=#{`aws --profile #{aws_profile} configure get aws_secret_access_key`.chomp} \
      --env AWS_DEFAULT_REGION=#{region} \
      -v #{Rails.root.join('terraform', env)}:/workspace \
      -v #{Rails.root.join('terraform', 'modules')}:/workspace/modules \
      -w /workspace \
      -it \
      hashicorp/terraform:0.13.0 \
      destroy \
      -var='project_name=#{PROJECT_NAME}' \
      -var='master_key=#{`cat #{Rails.root.join('config', 'master.key')}`}' \
      -var='region=#{region}' \
      -var='env=#{env}' \
      -var='db_username=#{db_username}' \
      -var='db_password=#{db_password}' \
      -var='db_name=#{db_name}'"

      Rake::Task['ebs:bastion:unpack'].invoke(env, aws_profile, region)
    end

    FileUtils.rm_rf(Rails.root.join('terraform', env))

    bucket_name = "#{PROJECT_NAME}-#{env}-tfstate"

    begin
      s3_client.head_bucket(bucket: bucket_name) # will check and throw error if bucket is not present

      s3_client.put_bucket_versioning(
        bucket: bucket_name,
        versioning_configuration: {
          mfa_delete: 'Disabled',
          status: 'Suspended'
        }
      )

      result = s3_client.list_object_versions(bucket: bucket_name)
      unless result.versions.empty?
        s3_client.delete_objects(
          bucket: bucket_name,
          delete: {
            objects: result.versions.map do |object|
              {
                key: object.key,
                version_id: object.version_id
              }
            end
          }
        )
      end

      unless result.delete_markers.empty?
        s3_client.delete_objects(
          bucket: bucket_name,
          delete: {
            objects: result.delete_markers.map do |object|
              {
                key: object.key,
                version_id: object.version_id
              }
            end
          }
        )
      end

      s3_client.delete_bucket_lifecycle(bucket: bucket_name)
      s3_client.delete_bucket(bucket: bucket_name)
    rescue Aws::S3::Errors::NotFound
      Ebs::Helper.announce "#{bucket_name} already destroyed"
      abort
    end

    Ebs::Helper.announce 'END - Destroyed infrastructure!'
  end

  desc 'For Pushing terraform error state'
  task :push_error_state, %i[
    env
    aws_profile
    region
  ] => :environment do |_, args|
    env, aws_profile, region = Ebs::Helper.inputs(args)

    sh "cd #{Rails.root.join('terraform', env)} && \
    docker run \
    --rm \
    --env AWS_ACCESS_KEY_ID=#{`aws --profile #{aws_profile} configure get aws_access_key_id`.chomp} \
    --env AWS_SECRET_ACCESS_KEY=#{`aws --profile #{aws_profile} configure get aws_secret_access_key`.chomp} \
    --env AWS_DEFAULT_REGION=#{region} \
    -v #{Rails.root.join('terraform', env)}:/workspace \
    -v #{Rails.root.join('terraform', 'modules')}:/workspace/modules \
    -w /workspace \
    -it \
    hashicorp/terraform:0.13.0 \
    state push errored.tfstate"

    Ebs::Helper.announce "'terraform push errored.tfstate' completed. Continue your previous action."
    Ebs::Helper.announce "rake ebs:destroy # if you were in the midst of destroying the infrastructure when the error happened"
    Ebs::Helper.announce "rake ebs:apply # if you were in the midst of apply new changes to the infrastructure when the error happened"
  end
end

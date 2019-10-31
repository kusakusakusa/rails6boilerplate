# frozen_string_literal: true

namespace :ebs do
  PROJECT_NAME = Rails.application.class.module_parent_name.downcase

  ####################
  ### Common Tasks ###
  ####################
  desc 'Checks before proceeding'
  task :checks, %i[
    env
    aws_profile
    region
  ] => :environment do |_, args|
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

  desc 'Generate private/public key'
  task :generate_ssh_keys, [:env] => :environment do |_, args|
    # these keys will be used for:
    # 1. generating aws keypair
    # 2. authentication key for private git repository
    private_key_file_name = 'production_keypair'
    filepath = "#{Rails.root}/#{private_key_file_name}"
    puts "START - Create private/public keys for #{args[:env]}"

    if File.exist? filepath
      puts 'Private key already created'
    else
      `ssh-keygen -t rsa -f #{filepath} -C #{private_key_file_name} -N ''`
      puts "chmod 400 private and public keys for #{args[:env]}"
      `chmod 400 #{filepath}`
      `chmod 400 #{filepath}.pub`
    end

    file = File.open(Rails.root.join('terraform', args[:env], 'keypair.tf'), 'w')
    file.puts <<~MSG
      resource "aws_key_pair" "main" {
        key_name = "${var.project_name}-${var.env}"
        public_key = "#{`cat #{filepath}.pub`.chomp}"
      }
    MSG
    file.close

    puts "END - Create private/public keys for #{args[:env]}"
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
    task :create_setup_tf, %i[
      env
      region
    ] => :environment do |_, args|
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
    task :create_variables_tf, %i[
      env
      region
    ] => :environment do |_, args|
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

    desc 'Create vpc.tf'
    task :create_vpc_tf, %i[
      env
      aws_profile
      region
    ] => :environment do |_, args|
      puts "START - Create vpc.tf for #{args[:env]}"

      begin
        aws_access_key_id = `aws --profile #{args[:aws_profile]} configure get aws_access_key_id`.chomp
        aws_secret_access_key = `aws --profile #{args[:aws_profile]} configure get aws_secret_access_key`.chomp
        ec2_client = Aws::EC2::Client.new(
          region: args[:region],
          access_key_id: aws_access_key_id,
          secret_access_key: aws_secret_access_key
        )
        resp = ec2_client.describe_availability_zones(
          filters: [
            {
              name: 'region-name',
              values: [args[:region]]
            }
          ]
        )

        file = File.open(Rails.root.join('terraform', args[:env], 'vpc.tf'), 'w')

        file.puts <<~MSG
          resource "aws_vpc" "main" {
            cidr_block = "10.0.0.0/16" # 65536 ip addresses

            tags = {
              Name = "${var.project_name}${var.env}"
            }
          }

          # IGW
          resource "aws_internet_gateway" "main" {
            vpc_id = aws_vpc.main.id

            tags = {
              Name = "${var.project_name}${var.env}"
            }
          }

          resource "aws_route_table" "igw" {
            vpc_id = aws_vpc.main.id

            tags = {
              Name = "igw-${var.project_name}${var.env}"
            }
          }

          resource "aws_route" "igw" {
            route_table_id = aws_route_table.igw.id
            destination_cidr_block = "0.0.0.0/0"
            gateway_id = aws_internet_gateway.main.id
          }

          # NGW
          resource "aws_eip" "nat" {
            vpc = true
          }

          resource "aws_nat_gateway" "main" {
            allocation_id = aws_eip.nat.id
            subnet_id = aws_subnet.public-#{resp[:availability_zones].first.zone_name}.id
            depends_on = ["aws_internet_gateway.main"]

            tags = {
              Name = "${var.project_name}${var.env}"
            }
          }

          resource "aws_route_table" "ngw" {
            vpc_id = aws_vpc.main.id

            tags = {
              Name = "ngw-${var.project_name}${var.env}"
            }
          }

          resource "aws_route" "ngw" {
            route_table_id = aws_route_table.ngw.id
            destination_cidr_block = "0.0.0.0/0"
            nat_gateway_id = aws_nat_gateway.main.id
          }

          # Security Groups
          resource "aws_security_group" "bastion" {
            name = "${var.project_name}${var.env}-bastion"
            description = "for bastion server"
            vpc_id = aws_vpc.main.id

            # ssh
            ingress {
              from_port = 22
              to_port = 22
              protocol = "tcp"
              # Please restrict your ingress to only necessary IPs and ports.
              # Opening to 0.0.0.0/0 can lead to security vulnerabilities
              # You may want to set a fixed ip address if you have a static ip
              cidr_blocks = ["0.0.0.0/0"]
            }

            tags = {
              Name = "${var.project_name}${var.env}"
            }
          }

          resource "aws_security_group" "web_server" {
            name = "${var.project_name}${var.env}-web-servers"
            description = "for Web servers"
            vpc_id = aws_vpc.main.id

            tags = {
              Name = "${var.project_name}${var.env}"
            }
          }

        MSG

        # public subnets (254 addresses)
        # public subnets have **igw** aws_route_table_association
        resp[:availability_zones].each.with_index do |az, index|
          file.puts <<~SUBNET_TF
            resource "aws_subnet" "public-#{az.zone_name}" {
              vpc_id = aws_vpc.main.id
              cidr_block = "10.0.#{100 + index}.0/24"

              tags = {
                Name = "public-#{az.zone_name}-${var.project_name}${var.env}"
              }
            }

            resource "aws_route_table_association" "public-#{az.zone_name}" {
              subnet_id = aws_subnet.public-#{az.zone_name}.id
              route_table_id = aws_route_table.igw.id
            }

          SUBNET_TF
        end

        # private subnets (254 addresses)
        # private subnets have **ngw** aws_route_table_association
        resp[:availability_zones].each.with_index do |az, index|
          file.puts <<~SUBNET_TF
            resource "aws_subnet" "private-#{az.zone_name}" {
              vpc_id = aws_vpc.main.id
              cidr_block = "10.0.#{1 + index}.0/24"

              tags = {
                Name = "private-#{az.zone_name}-${var.project_name}${var.env}"
              }
            }

            resource "aws_route_table_association" "private-#{az.zone_name}" {
              subnet_id = aws_subnet.private-#{az.zone_name}.id
              route_table_id = aws_route_table.ngw.id
            }

          SUBNET_TF
        end

        file.close
      rescue Aws::EC2::Errors::ServiceError
        # leave debug point here
        binding.pry
      end

      puts "END - Create vpc.tf for #{args[:env]}"
    end

    desc 'Create rds.tf'
    task :create_rds_tf, %i[
      env
      aws_profile
      region
    ] => :environment do |_, args|
      puts "START - Create rds.tf for #{args[:env]}"

      begin
        aws_access_key_id = `aws --profile #{args[:aws_profile]} configure get aws_access_key_id`.chomp
        aws_secret_access_key = `aws --profile #{args[:aws_profile]} configure get aws_secret_access_key`.chomp
        ec2_client = Aws::EC2::Client.new(
          region: args[:region],
          access_key_id: aws_access_key_id,
          secret_access_key: aws_secret_access_key
        )
        resp = ec2_client.describe_availability_zones(
          filters: [
            {
              name: 'region-name',
              values: [args[:region]]
            }
          ]
        )

        file = File.open(Rails.root.join('terraform', args[:env], 'rds.tf'), 'w')
        file.puts <<~MSG
          resource "aws_db_instance" "default" {
            allocated_storage = 20
            storage_type = "gp2"
            engine = "mysql"
            engine_version = "5.7"
            instance_class = "db.t2.micro"
            name = "#{Rails.application.credentials.dig(:production, :database, :db)}"
            username = "#{Rails.application.credentials.dig(:production, :database, :username)}"
            password = "#{Rails.application.credentials.dig(:production, :database, :password)}"

            skip_final_snapshot = false
            final_snapshot_identifier = "rds-${var.project_name}${var.env}-#{SecureRandom.alphanumeric(6)}"

            tags = {
              Name = "rds-${var.project_name}${var.env}"
            }
          }

          resource "aws_db_subnet_group" "main" {
            name = "db-private-subnets"
            subnet_ids = [
        MSG

        resp[:availability_zones].each.with_index do |az, index|
          file.puts <<~SUBNET_TF
                aws_subnet.private-#{az.zone_name}.id,
          SUBNET_TF
        end

        file.puts <<~MSG
            ]

            tags = {
              Name = "subnet-group-${var.project_name}${var.env}"
            }
          }
        MSG
        file.close
      rescue Aws::EC2::Errors::ServiceError
        # leave debug point here
        binding.pry
      end

      puts "END - Create rds.tf for #{args[:env]}"
    end

    desc 'Create ebs.tf'
    task :create_ebs_tf, %i[
      env
      aws_profile
      region
    ] => :environment do |_, args|
      puts "START - Create ebs.tf for #{args[:env]}"

      aws_access_key_id = `aws --profile #{args[:aws_profile]} configure get aws_access_key_id`.chomp
      aws_secret_access_key = `aws --profile #{args[:aws_profile]} configure get aws_secret_access_key`.chomp
      ec2_client = Aws::EC2::Client.new(
        region: args[:region],
        access_key_id: aws_access_key_id,
        secret_access_key: aws_secret_access_key
      )
      resp = ec2_client.describe_availability_zones(
        filters: [
          {
            name: 'region-name',
            values: [args[:region]]
          }
        ]
      )

      file = File.open(Rails.root.join('terraform', args[:env], 'ebs.tf'), 'w')
      file.puts <<~MSG
        # https://registry.terraform.io/modules/cloudposse/elastic-beanstalk-environment/aws/0.17.0
        module "elastic-beanstalk-application" {
          source  = "cloudposse/elastic-beanstalk-application/aws"
          version = "0.4.0"

          # 1 required variable
          name = "${var.project_name}${var.env}-ebs-application"
        }

        module "elastic-beanstalk-environment" {
          source = "cloudposse/elastic-beanstalk-environment/aws"
          version = "0.17.0"

          # 6 required variables
          application_subnets = [
      MSG

      resp[:availability_zones].each do |az|
        file.puts <<~MSG
              aws_subnet.private-#{az.zone_name}.id,
        MSG
      end

      file.puts <<~MSG
          ]
          elastic_beanstalk_application_name = module.elastic-beanstalk-application.elastic_beanstalk_application_name
          name = "app"
          region = var.region
          solution_stack_name = "64bit Amazon Linux 2018.03 v2.11.0 running Ruby 2.6 (Puma)"
          vpc_id = aws_vpc.main.id

          # optional variables
          allowed_security_groups = [
            aws_security_group.web_server.id
          ]
          autoscale_min = 1
          autoscale_max = 2 # min cannot eq max
          availability_zone_selector = "Any"
          healthcheck_url = "/healthcheck" # default is /healthcheck
          instance_type = "t2.micro" # default is t2.micro
          keypair = ""
          loadbalancer_subnets = [
      MSG

      resp[:availability_zones].each do |az|
        file.puts <<~MSG
              aws_subnet.public-#{az.zone_name}.id,
        MSG
      end

      file.puts <<~MSG
          ]
          stage = var.env
        }
      MSG
      file.close

      puts "END - Create ebs.tf for #{args[:env]}"
    end
  end

  ##################
  ### Main Tasks ###
  ##################
  desc 'For production env with proper infrastructure'
  task init: :environment do
    FileUtils.mkdir_p(Rails.root.join('terraform', 'production'))

    env = aws_profile = region = ''

    ## TODO env set as production for now?
    env = 'production'
    # loop do
    #   puts 'Enter environment:'
    #   env = STDIN.gets.chomp

    #   break unless env.blank?

    #   puts 'Nothing entered. Please enter an environment (eg staging, uat)'
    # end

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

    Rake::Task['ebs:checks'].invoke(env, aws_profile, region)
    Rake::Task['ebs:generate_ssh_keys'].invoke(env, aws_profile, region)
    Rake::Task['ebs:terraform:create_tfstate_bucket'].invoke(env, aws_profile, region)
    Rake::Task['ebs:terraform:create_setup_tf'].invoke(env, region)
    Rake::Task['ebs:terraform:create_variables_tf'].invoke(env, region)
    Rake::Task['ebs:terraform:create_vpc_tf'].invoke(env, aws_profile, region)
    Rake::Task['ebs:terraform:create_rds_tf'].invoke(env, aws_profile, region)
    Rake::Task['ebs:terraform:create_ebs_tf'].invoke(env, aws_profile, region)

    sh "cd #{Rails.root.join('terraform', env)} && \
    docker run \
    --rm \
    --env AWS_ACCESS_KEY_ID=#{`aws --profile #{aws_profile} configure get aws_access_key_id`.chomp} \
    --env AWS_SECRET_ACCESS_KEY=#{`aws --profile #{aws_profile} configure get aws_secret_access_key`.chomp} \
    -v #{Rails.root.join('terraform', env)}:/workspace \
    -w /workspace \
    -it \
    hashicorp/terraform:0.12.12 \
    init"

    sh "cd #{Rails.root.join('terraform', env)} && \
    docker run \
    --rm \
    --env AWS_ACCESS_KEY_ID=#{`aws --profile #{aws_profile} configure get aws_access_key_id`.chomp} \
    --env AWS_SECRET_ACCESS_KEY=#{`aws --profile #{aws_profile} configure get aws_secret_access_key`.chomp} \
    -v #{Rails.root.join('terraform', env)}:/workspace \
    -w /workspace \
    -it \
    hashicorp/terraform:0.12.12 \
    apply"
  end

  desc 'For production env with proper infrastructure'
  task destroy: :environment do
    env = aws_profile = region = ''

    ## TODO env set as production for now?
    env = 'production'
    # loop do
    #   puts 'Enter environment:'
    #   env = STDIN.gets.chomp

    #   break unless env.blank?

    #   puts 'Nothing entered. Please enter an environment (eg staging, uat)'
    # end

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

    Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

    sh "cd #{Rails.root.join('terraform', env)} && \
    docker run \
    --rm \
    --env AWS_ACCESS_KEY_ID=#{`aws --profile #{aws_profile} configure get aws_access_key_id`.chomp} \
    --env AWS_SECRET_ACCESS_KEY=#{`aws --profile #{aws_profile} configure get aws_secret_access_key`.chomp} \
    -v #{Rails.root.join('terraform', env)}:/workspace \
    -w /workspace \
    -it \
    hashicorp/terraform:0.12.12 \
    destroy"
  end
end

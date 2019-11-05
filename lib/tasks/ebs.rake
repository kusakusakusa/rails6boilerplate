# frozen_string_literal: true

module Ebs
  class Helper
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

      abort('There are no reservations. Make sure to setup your bastion servers first by running the command below:\n\n\trake ebs:bastion:up\n') if results.reservations.count.zero?

      instances = results.reservations.first.instances

      abort('There are more than 1 bastion servers.\nThis should not happen. Please check!') if instances.count > 1

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
      abort('More than 1 db instances found.\nThis should not happen. Please check!\n') if result.db_instances.count > 1
      db_instance = result.db_instances.first

      forwarded_port_no = rand(10_000..60_000)
      puts "\n  Tunneled port: #{forwarded_port_no}\n"

      gateway = Net::SSH::Gateway.new(
        bastion.public_ip_address,
        'ec2-user',
        keys: ["#{Rails.root}/production_keypair"]
      )
      abort('\nGateway not active!\n') unless gateway.active?
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
        ec2_client = Ebs::Helper.ec2_client(
          aws_profile: args[:aws_profile],
          region: args[:region]
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

            tags = {
              Name = "${var.project_name}${var.env}"
            }
          }

          # allow ssh into bastion
          resource "aws_security_group_rule" "ssh-bastion-world" {
            type = "ingress"
            from_port = 22
            to_port = 22
            protocol = "tcp"
            # Please restrict your ingress to only necessary IPs and ports.
            # Opening to 0.0.0.0/0 can lead to security vulnerabilities
            # You may want to set a fixed ip address if you have a static ip
            security_group_id = aws_security_group.bastion.id
            cidr_blocks = ["0.0.0.0/0"]
          }

          # allow bastion to ssh into private instances
          resource "aws_security_group_rule" "ssh-bastion-web_server" {
            type = "egress"
            from_port = 22
            to_port = 22
            protocol = "tcp"
            security_group_id = aws_security_group.bastion.id
            source_security_group_id = aws_security_group.web_server.id
          }

          # allow bastion to connect out into rds
          resource "aws_security_group_rule" "ssh-bastion-rds" {
            type = "egress"
            from_port = 3306
            to_port = 3306
            protocol = "tcp"
            security_group_id = aws_security_group.bastion.id
            source_security_group_id = aws_security_group.rds.id
          }

          resource "aws_security_group" "web_server" {
            name = "${var.project_name}${var.env}-web-servers"
            description = "for Web servers"
            vpc_id = aws_vpc.main.id

            tags = {
              Name = "${var.project_name}${var.env}"
            }
          }

          # allow bastion to ssh into private instances
          # rule will be duplicated with elastic beanstalk default security groups
          resource "aws_security_group_rule" "ssh-web_server-bastion" {
            type = "ingress"
            from_port = 22
            to_port = 22
            protocol = "tcp"
            security_group_id = aws_security_group.web_server.id
            source_security_group_id = aws_security_group.bastion.id
          }

        MSG

        # public subnets (254 addresses)
        # public subnets have **igw** aws_route_table_association
        resp[:availability_zones].each.with_index do |az, index|
          file.puts <<~SUBNET_TF
            resource "aws_subnet" "public-#{az.zone_name}" {
              vpc_id = aws_vpc.main.id
              cidr_block = "10.0.#{100 + index}.0/24"
              availability_zone_id = "#{az.zone_id}"

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
              availability_zone_id = "#{az.zone_id}"

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
        ec2_client = Ebs::Helper.ec2_client(
          aws_profile: args[:aws_profile],
          region: args[:region]
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
          resource "aws_db_instance" "main" {
            allocated_storage = 20
            storage_type = "gp2"
            engine = "mysql"
            engine_version = "5.7"
            instance_class = "db.t2.micro"
            identifier = "rds-${var.project_name}${var.env}"
            name = "#{Rails.application.credentials.dig(:production, :database, :db)}"
            username = "#{Rails.application.credentials.dig(:production, :database, :username)}"
            password = "#{Rails.application.credentials.dig(:production, :database, :password)}"

            skip_final_snapshot = false
            # notes time of creation of rds.tf file
            final_snapshot_identifier = "rds-${var.project_name}${var.env}-#{DateTime.now.to_i}"

            vpc_security_group_ids = [aws_security_group.rds.id]
            db_subnet_group_name = aws_db_subnet_group.main.id

            tags = {
              Name = "rds-${var.project_name}${var.env}"
            }
          }

          resource "aws_security_group" "rds" {
            name = "${var.project_name}${var.env}-rds"
            description = "for rds"
            vpc_id = aws_vpc.main.id

            tags = {
              Name = "${var.project_name}${var.env}"
            }
          }

          resource "aws_security_group_rule" "mysql-rds-web_server" {
            type = "ingress"
            from_port = 3306
            to_port = 3306
            protocol = "tcp"
            security_group_id = aws_security_group.rds.id
            source_security_group_id = aws_security_group.web_server.id
          }

          resource "aws_security_group_rule" "mysql-rds-bastion" {
            type = "ingress"
            from_port = 3306
            to_port = 3306
            protocol = "tcp"
            security_group_id = aws_security_group.rds.id
            source_security_group_id = aws_security_group.bastion.id
          }

          resource "aws_db_subnet_group" "main" {
            name = "db-private-subnets"
            subnet_ids = [
        MSG

        resp[:availability_zones].each do |az|
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

      ec2_client = Ebs::Helper.ec2_client(
        aws_profile: args[:aws_profile],
        region: args[:region]
      )
      resp = ec2_client.describe_availability_zones(
        filters: [
          {
            name: 'region-name',
            values: [args[:region]]
          }
        ]
      )

      dbname = Rails.application.credentials.dig(args[:env].to_sym, :database, :db)
      username = Rails.application.credentials.dig(args[:env].to_sym, :database, :username)
      password = Rails.application.credentials.dig(args[:env].to_sym, :database, :password)

      file = File.open(Rails.root.join('terraform', args[:env], 'ebs.tf'), 'w')
      file.puts <<~MSG
        # with reference to
        # https://github.com/wardviaene/terraform-demo/blob/master/elasticbeanstalk.tf
        # https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/command-options-general.html

        resource "aws_elastic_beanstalk_application" "main" {
          name = "eb-${var.project_name}${var.env}"
          description = "Elastic Beanstalk"
        }

        resource "aws_elastic_beanstalk_environment" "main" {
          name = "eb-env-${var.project_name}${var.env}"
          application = aws_elastic_beanstalk_application.main.name
          solution_stack_name = "64bit Amazon Linux 2018.03 v2.11.0 running Ruby 2.6 (Puma)"

          #################
          # command-options-general-ec2vpc
          #################
          setting {
            namespace = "aws:ec2:vpc"
            name = "VPCId"
            value = aws_vpc.main.id
          }

          setting {
            namespace = "aws:ec2:vpc"
            name = "ELBScheme"
            value = "public"
          }

          setting {
            namespace = "aws:ec2:vpc"
            name = "AssociatePublicIpAddress"
            value = "false"
          }

          setting {
            namespace = "aws:ec2:vpc"
            name = "ELBSubnets"
            value = "#{resp[:availability_zones].map do |az|
              "\${aws_subnet.public-#{az.zone_name}.id}"
            end.join(',')}"
          }

          setting {
            namespace = "aws:ec2:vpc"
            name = "Subnets"
            value = "#{resp[:availability_zones].map do |az|
              "\${aws_subnet.private-#{az.zone_name}.id}"
            end.join(',')}"
          }

          #################
          # command-options-general-autoscalinglaunchconfiguration
          #################
          setting {
            namespace = "aws:autoscaling:launchconfiguration"
            name = "SecurityGroups"
            value = aws_security_group.web_server.id
          }

          setting {
            namespace = "aws:autoscaling:launchconfiguration"
            name = "EC2KeyName"
            value = aws_key_pair.main.id
          }

          setting {
            namespace = "aws:autoscaling:launchconfiguration"
            name = "InstanceType"
            value = "t2.small"
          }

          #################

          setting {
            namespace = "aws:elasticbeanstalk:environment"
            name = "ServiceRole"
            value = "eb-${var.project_name}${var.env}-service-role"
          }

          #################

          setting {
            namespace = "aws:elb:loadbalancer"
            name = "CrossZone"
            value = "true"
          }

          #################
          # command-options-general-elasticbeanstalkcommand
          #################
          setting {
            namespace = "aws:elasticbeanstalk:command"
            name = "BatchSize"
            value = "30"
          }
          setting {
            namespace = "aws:elasticbeanstalk:command"
            name = "BatchSize"
            value = "30"
          }
          setting {
            namespace = "aws:elasticbeanstalk:command"
            name = "BatchSizeType"
            value = "Percentage"
          }

          #################
          # command-options-general-autoscalingasg
          #################
          setting {
            namespace = "aws:autoscaling:asg"
            name = "Availability Zones"
            value = "Any #{resp[:availability_zones].count}"
          }

          setting {
            namespace = "aws:autoscaling:asg"
            name = "MinSize"
            value = "2"
          }

          setting {
            namespace = "aws:autoscaling:asg"
            name = "MaxSize"
            value = "2"
          }
          #################

          setting {
            namespace = "aws:autoscaling:updatepolicy:rollingupdate"
            name = "RollingUpdateType"
            value = "Health"
          }

          #################
          # command-options-general-elasticbeanstalkapplicationenvironment
          #################
          setting {
            namespace = "aws:elasticbeanstalk:application:environment"
            name = "DATABASE_URL"
            value = "mysql2://#{username}:#{password}@${aws_db_instance.main.endpoint}/#{dbname}"
          }

          # serve assets using static files
          setting {
            namespace = "aws:elasticbeanstalk:application:environment"
            name = "RAILS_SERVE_STATIC_FILES"
            value = "true"
          }

          setting {
            namespace = "aws:elasticbeanstalk:application:environment"
            name = "RAILS_MASTER_KEY"
            value = "#{`cat #{Rails.root.join('config')}/master.key`}"
          }

          setting {
            namespace = "aws:elasticbeanstalk:application:environment"
            name = "RAILS_ENV"
            value = "#{args[:env]}"
          }

          setting {
            namespace = "aws:elasticbeanstalk:application:environment"
            name = "RACK_ENV"
            value = "#{args[:env]}"
          }

          tags = {
            Name = "eb-${var.project_name}${var.env}"
          }
        }

        output "endpoint_url" {
          value = aws_elastic_beanstalk_environment.main.endpoint_url
        }
      MSG

      # ebs user
      file.puts <<~MSG

        module "eb-iam_policy" {
          source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
          version = "~> 2.0"

          name = "eb-policy-${var.project_name}${var.env}"
          description = "EB policy for ${var.project_name}-${var.env}"

          # AWSElasticBeanstalkFullAccess full policy referenced from
          # https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/concepts-roles-user.html
          policy = <<EOF
        {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Action": [
                "elasticbeanstalk:*",
                "ec2:*",
                "ecs:*",
                "ecr:*",
                "elasticloadbalancing:*",
                "autoscaling:*",
                "cloudwatch:*",
                "s3:*",
                "sns:*",
                "cloudformation:*",
                "dynamodb:*",
                "rds:*",
                "sqs:*",
                "logs:*",
                "iam:GetPolicyVersion",
                "iam:GetRole",
                "iam:PassRole",
                "iam:ListRolePolicies",
                "iam:ListAttachedRolePolicies",
                "iam:ListInstanceProfiles",
                "iam:ListRoles",
                "iam:ListServerCertificates",
                "acm:DescribeCertificate",
                "acm:ListCertificates",
                "codebuild:CreateProject",
                "codebuild:DeleteProject",
                "codebuild:BatchGetBuilds",
                "codebuild:StartBuild"
              ],
              "Resource": "*"
            },
            {
              "Effect": "Allow",
              "Action": [
                "iam:AddRoleToInstanceProfile",
                "iam:CreateInstanceProfile",
                "iam:CreateRole"
              ],
              "Resource": [
                "arn:aws:iam::*:role/aws-elasticbeanstalk*",
                "arn:aws:iam::*:instance-profile/aws-elasticbeanstalk*"
              ]
            },
            {
              "Effect": "Allow",
              "Action": [
                "iam:CreateServiceLinkedRole"
              ],
              "Resource": [
                "arn:aws:iam::*:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling*"
              ],
              "Condition": {
                "StringLike": {
                  "iam:AWSServiceName": "autoscaling.amazonaws.com"
                }
              }
            },
            {
              "Effect": "Allow",
              "Action": [
                "iam:CreateServiceLinkedRole"
              ],
              "Resource": [
                "arn:aws:iam::*:role/aws-service-role/elasticbeanstalk.amazonaws.com/AWSServiceRoleForElasticBeanstalk*"
              ],
              "Condition": {
                "StringLike": {
                  "iam:AWSServiceName": "elasticbeanstalk.amazonaws.com"
                }
              }
            },
            {
              "Effect": "Allow",
              "Action": [
                "iam:AttachRolePolicy"
              ],
              "Resource": "*",
              "Condition": {
                "StringLike": {
                  "iam:PolicyArn": [
                    "arn:aws:iam::aws:policy/AWSElasticBeanstalk*",
                    "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalk*"
                  ]
                }
              }
            }
          ]
        }
        EOF
        }

        module "eb-iam_user" {
          source  = "terraform-aws-modules/iam/aws//modules/iam-user"
          version = "~> 2.0"

          create_iam_access_key = "true"
          create_iam_user_login_profile = "false"

          name = "eb-${var.project_name}${var.env}"

          tags = {
            Name = "eb-${var.project_name}${var.env}"
          }
        }

        resource "aws_iam_user_policy_attachment" "eb" {
          user = module.eb-iam_user.this_iam_user_name
          policy_arn = module.eb-iam_policy.arn
        }

        output "eb-user-access_key_id" {
          value = module.eb-iam_user.this_iam_access_key_id
        }

        output "eb-user-secret_access_key" {
          value = module.eb-iam_user.this_iam_access_key_secret
        }
      MSG
      file.close

      puts "END - Create ebs.tf for #{args[:env]}"
    end
  end

  #####################
  ### Bastion Tasks ###
  #####################
  namespace :bastion do
    desc 'Unpack bastion server AMI'
    task unpack: :environment do
      env, aws_profile, region = Ebs::Helper.inputs

      Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

      puts 'Unpacking bastion AMI...'

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

      ec2_client.deregister_image(
        image_id: ami.image_id
      )

      puts 'Unpacked bastion AMI'
    end

    desc 'Setup bastion server'
    task up: :environment do
      env, aws_profile, region = Ebs::Helper.inputs

      Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

      puts 'Setting up bastion...'

      Rake::Task['ebs:bastion:pack'].invoke(env, aws_profile, region)

      sh "cd #{Rails.root.join('terraform', env)} && \
        docker run \
        --rm \
        --env AWS_ACCESS_KEY_ID=#{`aws --profile #{aws_profile} configure get aws_access_key_id`.chomp} \
        --env AWS_SECRET_ACCESS_KEY=#{`aws --profile #{aws_profile} configure get aws_secret_access_key`.chomp} \
        -v #{Rails.root.join('terraform', env)}:/workspace \
        -v #{Rails.root}/production_keypair:/workspace/production_keypair \
        -w /workspace \
        -it \
        hashicorp/terraform:0.12.12 \
        apply -auto-approve"

      if File.exist?(Rails.root.join('terraform', 'production', 'ebs.tf'))
        ec2_client = Ebs::Helper.ec2_client(
          aws_profile: aws_profile,
          region: region
        )

        # with reference to
        # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html
        ami = ec2_client.describe_images(
          filters: [
            {
              name: 'name',
              values: ["bastion-#{PROJECT_NAME}-#{env}"]
            }
          ],
          owners: ['self']
        ).images.max_by(&:creation_date) # latest image

        resp = ec2_client.describe_availability_zones(
          filters: [
            {
              name: 'region-name',
              values: [region]
            }
          ]
        )

        file = File.open(Rails.root.join('terraform', env, 'bastion.tf'), 'w')
        file.puts <<~MSG
          resource "aws_instance" "bastion" {
            ami = "#{ami.image_id}"
            associate_public_ip_address = true
            instance_type = "t2.nano"
            subnet_id = aws_subnet.public-#{resp[:availability_zones].first.zone_name}.id
            vpc_security_group_ids = ["${aws_security_group.bastion.id}"]
            key_name = aws_key_pair.main.key_name

            tags = {
              Name = "bastion-${var.project_name}${var.env}"
            }
          }

          output "bastion_public_ip" {
            value = aws_instance.bastion.public_ip
          }
        MSG
        file.close

        # mount production_keypair to root of /workspace in container
        sh "cd #{Rails.root.join('terraform', env)} && \
          docker run \
          --rm \
          --env AWS_ACCESS_KEY_ID=#{`aws --profile #{aws_profile} configure get aws_access_key_id`.chomp} \
          --env AWS_SECRET_ACCESS_KEY=#{`aws --profile #{aws_profile} configure get aws_secret_access_key`.chomp} \
          -v #{Rails.root.join('terraform', env)}:/workspace \
          -v #{Rails.root}/production_keypair:/workspace/production_keypair \
          -w /workspace \
          -it \
          hashicorp/terraform:0.12.12 \
          apply -auto-approve"
      else
        abort('`ebs.tf` file not found!\nSetup your EBS environment first by running:\n\n  rake ebs:init\n')
      end

      puts 'Set up bastion!'
    end

    desc 'Shutdown bastion server'
    task down: :environment do
      puts 'Shutting up bastion...'

      env, aws_profile, region = Ebs::Helper.inputs

      if File.exist?(Rails.root.join('terraform', 'production', 'bastion.tf'))

        FileUtils.rm(Rails.root.join('terraform', 'production', 'bastion.tf'))

        sh "cd #{Rails.root.join('terraform', env)} && \
          docker run \
          --rm \
          --env AWS_ACCESS_KEY_ID=#{`aws --profile #{aws_profile} configure get aws_access_key_id`.chomp} \
          --env AWS_SECRET_ACCESS_KEY=#{`aws --profile #{aws_profile} configure get aws_secret_access_key`.chomp} \
          -v #{Rails.root.join('terraform', env)}:/workspace \
          -w /workspace \
          -it \
          hashicorp/terraform:0.12.12 \
          apply -auto-approve"
      else
        abort('`bastion.tf` file not found!\nDo nothing here!\n')
      end

      puts 'Shutdown bastion!'
    end

    desc 'Pack bastion server AMI'
    task :pack, %i[
      env
      aws_profile
      region
    ] => :environment do |_, args|
      puts 'Packing bastion...'

      ec2_client = Ebs::Helper.ec2_client(
        aws_profile: args[:aws_profile],
        region: args[:region]
      )

      bastion_ami = ec2_client.describe_images(
        filters: [
          {
            name: 'name',
            values: ["bastion-#{PROJECT_NAME}-#{args[:env]}"]
          }
        ],
        owners: ['self']
      ).images.max_by(&:creation_date)

      if bastion_ami.nil?
        # with reference to
        # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html
        ami = ec2_client.describe_images(
          filters: [
            {
              name: 'name',
              values: ['amzn2-ami-hvm-2.0.????????.?-x86_64-gp2']
            }
          ],
          owners: ['amazon']
        ).images.max_by(&:creation_date) # latest image

        file = File.open(Rails.root.join('terraform', args[:env], 'bastion.json'), 'w')
        file.puts <<~MSG
          {
            "variables": {
              "project_name": "#{PROJECT_NAME}",
              "region": "#{args[:region]}",
              "env": "#{args[:env]}"
            },
            "builders": [
              {
                "type": "amazon-ebs",
                "region": "{{user `region`}}",
                "source_ami": "#{ami.image_id}",
                "instance_type": "t2.nano",
                "ssh_username": "ec2-user",
                "ami_name": "bastion-{{user `project_name`}}-{{user `env`}}",
                "shutdown_behavior": "terminate",
                "run_tags": {
                  "Name": "{{user `project_name`}}",
                  "Env": "{{user `env`}}"
                },
                "run_volume_tags": {
                  "Name": "{{user `project_name`}}",
                  "Env": "{{user `env`}}"
                },
                "snapshot_tags": {
                  "Name": "{{user `project_name`}}",
                  "Env": "{{user `env`}}"
                }
              }
            ],
            "provisioners": [
              {
                "type": "shell",
                "inline": [
                  "sudo wget https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm",
                  "sudo yum -y localinstall mysql57-community-release-el7-11.noarch.rpm ",
                  "sudo yum -y install mysql-community-client mysql-community-common mysql-community-libs mysql-community-server",
                  "sudo service mysqld restart"
                ]
              }
            ]
          }
        MSG
        file.close

        sh "cd #{Rails.root.join('terraform', args[:env])} && \
          docker run \
          -it \
          --rm \
          --env AWS_ACCESS_KEY_ID=#{`aws --profile #{args[:aws_profile]} configure get aws_access_key_id`.chomp} \
          --env AWS_SECRET_ACCESS_KEY=#{`aws --profile #{args[:aws_profile]} configure get aws_secret_access_key`.chomp} \
          -v #{Rails.root.join('terraform', args[:env])}/bastion.json:/workspace/bastion.json \
          -w /workspace \
          hashicorp/packer:light \
          build -force bastion.json"

        puts 'Packed bastion AMI!'
      else
        puts('Bastion image has already been packed!')
      end
      puts ''
    end

    desc 'SSH into private servers via bastion'
    task ssh: :environment do
      env, aws_profile, region = Ebs::Helper.inputs

      Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

      puts 'ssh into bastion...'

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

      abort('There are no reservations. Make sure to setup the ebs instance first by running the comand:\n\n\trake ebs:init\n') if results.reservations.count.zero?

      private_ip_addresses = results.reservations.map do |reservation|
        reservation.instances.map(&:private_ip_address)
      end.flatten

      abort('There are no private_ip_addresses.\nThis should not happen. Please check!') if private_ip_addresses.count.zero?

      ##### SSH time #####
      # TODO ask for private ip address choice
      # TODO check local machine has ssh agent

      puts 'Clear ssh agent identities'
      sh 'ssh-add -D'
      puts 'Add keypair to ssh agent'
      sh "ssh-add -K #{Rails.root}/production_keypair"
      puts "ssh into bastion then into private instance (#{private_ip_addresses.first})"
      sh('ssh ' \
      '-tt ' \
      '-A ' \
      "ec2-user@#{bastion.public_ip_address} " \
      "-o 'UserKnownHostsFile /dev/null' " \
      '-o StrictHostKeyChecking=no ' \
      "\"ssh ec2-user@#{private_ip_addresses.first} " \
      "-o 'UserKnownHostsFile /dev/null' " \
      '-o StrictHostKeyChecking=no"')
      puts 'Clear ssh agent identities'
      sh 'ssh-add -D'

      puts 'ssh-ed into bastion!'
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
    end

    desc 'Seed database'
    task seed: :environment do
      env, aws_profile, region = Ebs::Helper.inputs

      Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

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
    end

    desc 'Drop, create, migrate and seed database'
    task reseed: :environment do
      env, aws_profile, region = Ebs::Helper.inputs

      Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

      puts "You are reseeding the #{env} database for #{PROJECT_NAME}. Are you sure you want to proceed? (y for yes)"
      reply = STDIN.gets.chomp
      abort if reply.downcase != 'y'

      Ebs::Helper.tunnel(
        env: env,
        aws_profile: aws_profile,
        region: region
      ) do |forwarded_port_no|
        dbname = Rails.application.credentials.dig(env.to_sym, :database, :db)
        username = Rails.application.credentials.dig(env.to_sym, :database, :username)
        password = Rails.application.credentials.dig(env.to_sym, :database, :password)

        sh "DATABASE_URL=mysql2://#{username}:#{password}@127.0.0.1:#{forwarded_port_no}/#{dbname} DISABLE_DATABASE_ENVIRONMENT_CHECK=1 RAILS_ENV=#{env} bundle exec rails db:drop"
        sh "DATABASE_URL=mysql2://#{username}:#{password}@127.0.0.1:#{forwarded_port_no}/#{dbname} RAILS_ENV=#{env} bundle exec rails db:create"
        sh "DATABASE_URL=mysql2://#{username}:#{password}@127.0.0.1:#{forwarded_port_no}/#{dbname} RAILS_ENV=#{env} bundle exec rails db:migrate"
        sh "DATABASE_URL=mysql2://#{username}:#{password}@127.0.0.1:#{forwarded_port_no}/#{dbname} RAILS_ENV=#{env} bundle exec rails db:seed"
      end
    end
  end

  ##################
  ### Main Tasks ###
  ##################
  desc 'For production env with proper infrastructure'
  task init: :environment do
    env, aws_profile, region = Ebs::Helper.inputs

    FileUtils.mkdir_p(Rails.root.join('terraform', 'production'))

    Rake::Task['ebs:checks'].invoke(env, aws_profile, region)
    Rake::Task['ebs:generate_ssh_keys'].invoke(env, aws_profile, region)
    Rake::Task['ebs:terraform:create_tfstate_bucket'].invoke(env, aws_profile, region)
    Rake::Task['ebs:terraform:create_setup_tf'].invoke(env, region)
    Rake::Task['ebs:terraform:create_variables_tf'].invoke(env, region)
    Rake::Task['ebs:terraform:create_vpc_tf'].invoke(env, aws_profile, region)
    Rake::Task['ebs:terraform:create_rds_tf'].invoke(env, aws_profile, region)
    Rake::Task['ebs:terraform:create_ebs_tf'].invoke(env, aws_profile, region)

    Rake::Task['ebs:apply'].invoke(env, aws_profile)
  end

  task :apply, %i[
    env
    aws_profile
  ] => :environment do |_, args|
    env, aws_profile, region = Ebs::Helper.inputs(args)

    FileUtils.mkdir_p(Rails.root.join('terraform', 'production'))

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
    env, aws_profile, region = Ebs::Helper.inputs

    Rake::Task['ebs:checks'].invoke(env, aws_profile, region)

    puts 'Destroying infrastructure...'

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

    puts 'Destroyed infrastructure!'
  end
end

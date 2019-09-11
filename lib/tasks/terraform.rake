# frozen_string_literal: true

namespace :terraform do
  namespace :staging do
    desc 'Setup terraform for default staging env'
    task init: :environment do
      puts 'Enter your AWS named profile:'
      aws_profile = STDIN.gets.chomp
      AWS_ACCESS_KEY_ID = `aws --profile #{aws_profile} configure get aws_access_key_id`.chomp
      if AWS_ACCESS_KEY_ID.blank?
        abort('Please check your AWS named profile in ~/.aws/credentials file')
      end
      AWS_SECRET_ACCESS_KEY = `aws --profile #{aws_profile} configure get aws_secret_access_key`.chomp
      if AWS_SECRET_ACCESS_KEY.blank?
        abort('Please check your AWS named profile in ~/.aws/credentials file')
      end

      puts "AWS_ACCESS_KEY_ID is #{AWS_ACCESS_KEY_ID}"
      puts "AWS_SECRET_ACCESS_KEY is #{AWS_SECRET_ACCESS_KEY}"

      # constants
      PROJECT_NAME = Rails.application.class.module_parent_name.downcase
      REGION = 'us-east-1'
      PRIVATE_KEY_FILE_NAME = "#{Rails.application.class.module_parent_name}-staging"
      TFSTATE_BUCKET = "#{PROJECT_NAME}-tfstate"
      TFSTATE_KEY = 'staging/terraform.tfstate'
      LOGS_BUCKET = "#{PROJECT_NAME}-logs-bucket"

      puts ''
      puts '######################'
      puts ''

      # create terraform backend s3 bucket via aws-cli
      # which is assumed to be present on local machine
      tfstate_bucket = `aws s3 --profile #{aws_profile} ls | grep " #{TFSTATE_BUCKET}$"`.chomp
      if tfstate_bucket.blank?
        puts "Creating Terraform state bucket (#{TFSTATE_BUCKET})"
        `aws s3api create-bucket --bucket #{TFSTATE_BUCKET} --region #{REGION} --profile #{aws_profile}`

        sleep 2

        puts 'Uploading empty tfstate file'
        blank_filepath = Rails.root.join('tmp/tfstate')
        `touch #{blank_filepath}`
        `aws s3 cp #{blank_filepath} s3://#{TFSTATE_BUCKET}/#{TFSTATE_KEY} --profile #{aws_profile}`
        File.delete(blank_filepath)
      else
        puts "Terraform state bucket (#{TFSTATE_BUCKET}) already created!"
      end

      puts 'Enabling versioning'
      `aws s3api put-bucket-versioning --bucket #{TFSTATE_BUCKET} --profile #{aws_profile} --versioning-configuration Status=Enabled`

      tmp_versioning_filepath = Rails.root.join('tmp/tf_state_encryption_rule.json')
      puts 'Enabling encryption'
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
      `aws s3api put-bucket-encryption --bucket #{TFSTATE_BUCKET} --profile #{aws_profile} --server-side-encryption-configuration file://#{tmp_versioning_filepath}`
      File.delete(tmp_versioning_filepath)

      puts 'Enabling lifecycle'
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
      `aws s3api put-bucket-lifecycle-configuration --bucket #{TFSTATE_BUCKET} --profile #{aws_profile} --lifecycle-configuration file://#{tmp_lifecycle_filepath}`
      File.delete(tmp_lifecycle_filepath)

      puts ''
      puts '######################'
      puts ''

      create logs s3 bucket via aws-cli
      logs_bucket = `aws s3 --profile #{aws_profile} ls | grep " #{LOGS_BUCKET}$"`.chomp
      if logs_bucket.blank?
        puts "Creating logs bucket (#{LOGS_BUCKET})"
        `aws s3api create-bucket --bucket #{LOGS_BUCKET} --region #{REGION} --profile #{aws_profile}`
        puts "Enabling log-delivery-write acl for logs bucket (#{LOGS_BUCKET})"
        `aws s3api put-bucket-acl --bucket #{LOGS_BUCKET} --region #{REGION} --profile #{aws_profile} --acl log-delivery-write`
        puts "Enabling lifecycle logs bucket (#{LOGS_BUCKET})"
        tmp_lifecycle_filepath = Rails.root.join('tmp/tf_state_lifecycle_rule.json')
        file = File.open(tmp_lifecycle_filepath, 'w')
        file.puts <<~MSG
          {
              "Rules": [
                  {
                      "ID": "Remove all log files after 90 days",
                      "Status": "Enabled",
                      "Prefix": "",
                      "Expiration": {
                          "Days": 90
                      }
                  }
              ]
          }
        MSG
        file.close
        `aws s3api put-bucket-lifecycle-configuration --bucket #{LOGS_BUCKET} --profile #{aws_profile} --lifecycle-configuration file://#{tmp_lifecycle_filepath}`
        File.delete(tmp_lifecycle_filepath)

      else
        puts "Logs bucket (#{LOGS_BUCKET}) already created!"
      end

      puts ''
      puts '######################'
      puts ''

      # generate private/public key
      # these keys will be used for:
      # 1. generating aws keypair
      # 2. authentication key for private git repository
      if File.exist? "#{Rails.root.join('terraform', 'staging')}/#{PRIVATE_KEY_FILE_NAME}"
        puts 'Private key already created'
      else
        puts 'Create private key file for staging'
        sh "ssh-keygen -t rsa -f #{Rails.root.join('terraform', 'staging')}/#{PRIVATE_KEY_FILE_NAME} -C #{PRIVATE_KEY_FILE_NAME}"
      end

      puts ''
      puts '######################'
      puts ''

      # create terraform provisioning files
      puts "AWS REGION used is #{REGION}"

      puts 'Create setup.tf file for staging'
      file = File.open(Rails.root.join('terraform', 'staging', 'setup.tf'), 'w')
      file.puts <<~MSG
        # download all necessary plugins for terraform
        # set versions
        provider "aws" {
          version = "~> 2.24"
          region = "#{REGION}"
        }

        terraform {
          required_version = "~> 0.12.0"
          backend "s3" {
            bucket = "#{TFSTATE_BUCKET}"
            key = "#{TFSTATE_KEY}"
            region = "#{REGION}"
            access_key = "#{AWS_ACCESS_KEY_ID}"
            secret_key = "#{AWS_SECRET_ACCESS_KEY}"
          }
        }

        provider "null" {
          version = "~> 2.1"
        }
      MSG
      file.close

      puts 'Create variables.tf file for staging'
      file = File.open(Rails.root.join('terraform', 'staging', 'variables.tf'), 'w')
      file.puts <<~MSG
        variable "project_name" {
          type = string
          default = "#{PROJECT_NAME}"
        }

        variable "region" {
          type = string
          default = "#{REGION}"
        }

        variable "env" {
          type = string
          default = "staging"
        }
      MSG
      file.close

      puts 'Create secrets_bucket.tf file for staging to upload private and public keys'
      file = File.open(Rails.root.join('terraform', 'staging', 'secrets_bucket.tf'), 'w')
      file.puts <<~MSG
        module "secrets_bucket" {
          source = "trussworks/s3-private-bucket/aws"
          version = "~> 1.7.2"
          bucket = "${var.project_name}-secrets-bucket"
          logging_bucket = "#{LOGS_BUCKET}"

          tags = {
            Name = var.project_name
            Env = var.env
          }
        }

        resource "aws_s3_bucket_object" "private_key" {
          bucket = module.secrets_bucket.id
          key = "ssh_keys/#{PRIVATE_KEY_FILE_NAME}"
          source = "#{PRIVATE_KEY_FILE_NAME}"

          tags = {
            Name = var.project_name
            Env = var.env
          }
        }

        resource "aws_s3_bucket_object" "public_key" {
          bucket = module.secrets_bucket.id
          key = "ssh_keys/#{PRIVATE_KEY_FILE_NAME}.pub"
          source = "#{PRIVATE_KEY_FILE_NAME}.pub"

          tags = {
            Name = var.project_name
            Env = var.env
          }
        }

        # with reference to https://stackoverflow.com/a/52868251/2667545

        data "aws_iam_policy_document" "secrets_bucket" {
          statement {
            actions = ["sts:AssumeRole"]

            principals {
              type        = "Service"
              identifiers = ["ec2.amazonaws.com"]
            }
          }
        }

        resource "aws_iam_policy" "secrets_bucket" {
          name = "${module.secrets_bucket.id}-secrets_bucket_iam_policy"
          description = "Allow reading from the S3 bucket"

          policy = <<EOF
        {
          "Version":"2012-10-17",
          "Statement":[
            {
              "Effect":"Allow",
              "Action":[
                "s3:GetObject"
              ],
              "Resource":[
                "${module.secrets_bucket.arn}",
                "${module.secrets_bucket.arn}/*"
              ]
            },
            {
              "Effect":"Allow",
              "Action":[
                "s3:ListAllMyBuckets"
              ],
              "Resource":"*"
            }
          ]
        }
        EOF
        }

        resource "aws_iam_role" "secrets_bucket" {
          name = "${module.secrets_bucket.id}-iam_role"
          assume_role_policy = data.aws_iam_policy_document.secrets_bucket.json
        }

        resource "aws_iam_role_policy_attachment" "secrets_bucket" {
          role = aws_iam_role.secrets_bucket.name
          policy_arn = aws_iam_policy.secrets_bucket.arn
        }

        resource "aws_iam_instance_profile" "secrets_bucket" {
          name = "${module.secrets_bucket.id}-iam_instance_profile"
          role = aws_iam_role.secrets_bucket.name
        }
      MSG
      file.close

      puts 'Create ec2.tf file for staging'
      file = File.open(Rails.root.join('terraform', 'staging', 'ec2.tf'), 'w')
      file.puts <<~MSG
        resource "aws_key_pair" "this" {
          key_name   = var.project_name
          public_key = file("${path.module}/#{PRIVATE_KEY_FILE_NAME}.pub")
        }

        resource "aws_security_group" "this" {
          name = var.project_name
          description = "Security group for ${var.project_name} project"
          ingress {
            from_port = 80
            to_port = 80
            protocol = "tcp"
            cidr_blocks = [
              "0.0.0.0/0"
            ]
          }

          ingress {
            from_port = 22
            to_port = 22
            protocol = "tcp"
            cidr_blocks = [
              "0.0.0.0/0"
            ]
          }

          egress {
            from_port = 0
            to_port = 0
            protocol = "-1"
            cidr_blocks = [
              "0.0.0.0/0"
            ]
          }

          tags = {
            Name = var.project_name
            Env = var.env
          }
        }

        resource "aws_eip" "this" {
          vpc = true
          tags = {
            Name = var.project_name
            Env = var.env
          }

          # needs to persist?
          # lifecycle {
          #   prevent_destroy = true
          # }
        }

        resource "aws_eip_association" "this" {
          instance_id   = "${aws_instance.this.id}"
          allocation_id = "${aws_eip.this.id}"
        }

        resource "aws_instance" "this" {
          ami = "ami-035b3c7efe6d061d5" # Amazon Linux 2018
          instance_type = "t2.nano"
          availability_zone = "${var.region}a"
          key_name = aws_key_pair.this.key_name
          security_groups = [
            aws_security_group.this.name
          ]

          iam_instance_profile = aws_iam_instance_profile.secrets_bucket.name

          tags = {
            Name = var.project_name
            Env = var.env
          }
        }
      MSG
      file.close

      puts 'Create deploy.sh file for staging'

      ## deployment scripts ##

      file = File.open(Rails.root.join('terraform', 'staging', 'deploy.sh'), 'w')
      file.puts <<~MSG
        #!/usr/bin/env bash

        AWS_DEFAULT_REGION="#{REGION}"

        docker build \
          -t #{PROJECT_NAME}-staging:latest \
          --build-arg AWS_ACCESS_KEY_ID=#{AWS_ACCESS_KEY_ID} \
          --build-arg AWS_SECRET_ACCESS_KEY=#{AWS_SECRET_ACCESS_KEY} \
          #{Rails.root.join('terraform', 'staging')}

        docker run \
          --rm \
          -it \
          --env AWS_ACCESS_KEY_ID=#{AWS_ACCESS_KEY_ID} \
          --env AWS_SECRET_ACCESS_KEY=#{AWS_SECRET_ACCESS_KEY} \
          #{PROJECT_NAME}-staging \
          apply
      MSG
      file.close
      `chmod +x #{Rails.root.join('terraform', 'staging', 'deploy.sh')}`

      file = File.open(Rails.root.join('terraform', 'staging', 'destroy.sh'), 'w')
      file.puts <<~MSG
        #!/usr/bin/env bash

        AWS_DEFAULT_REGION="#{REGION}"

        docker run \
          --rm \
          -it \
          --env AWS_ACCESS_KEY_ID=#{AWS_ACCESS_KEY_ID} \
          --env AWS_SECRET_ACCESS_KEY=#{AWS_SECRET_ACCESS_KEY} \
          #{PROJECT_NAME}-staging \
          destroy
      MSG
      file.close
      `chmod +x #{Rails.root.join('terraform', 'staging', 'destroy.sh')}`
    end

    desc 'Deploy resources'
    task deploy: :environment do
      filepath = Rails.root.join('terraform', 'staging', 'deploy.sh').to_s
      if File.exist? filepath
        puts 'Initializing Terraform deploy script for staging environment'
        system(filepath)
      else
        abort("~/terraform/staging/deploy.sh script not present\nMake sure you run `rake terraform:staging:init`")
      end
    end

    desc 'Destroy resources'
    task destroy: :environment do
      filepath = Rails.root.join('terraform', 'staging', 'destroy.sh').to_s
      if File.exist? filepath
        puts 'Initializing Terraform destroy script for staging environment'
        system(filepath)
      else
        abort("~/terraform/staging/destroy.sh script not present\nMake sure you run `rake terraform:staging:init`")
      end
    end
  end
end

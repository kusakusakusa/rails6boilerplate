module Mina
  REGION = 'TODO'
  AWS_PROFILE = 'TODO'

  def self.s3_client
    @s3_client ||= (
      aws_access_key_id = `aws --profile #{AWS_PROFILE} configure get aws_access_key_id`.chomp
      aws_secret_access_key = `aws --profile #{AWS_PROFILE} configure get aws_secret_access_key`.chomp
      Aws::S3::Client.new(
        region: REGION,
        access_key_id: aws_access_key_id,
        secret_access_key: aws_secret_access_key
      )
    )
  end

  def self.ec2_client
    @ec2_client ||= (
      aws_access_key_id = `aws --profile #{AWS_PROFILE} configure get aws_access_key_id`.chomp
      aws_secret_access_key = `aws --profile #{AWS_PROFILE} configure get aws_secret_access_key`.chomp
      Aws::EC2::Client.new(
        region: REGION,
        access_key_id: aws_access_key_id,
        secret_access_key: aws_secret_access_key
      )
    )
  end

  def self.project_name
    Rails.application.class.module_parent_name.downcase
  end

  def self.tf_bucket_name
    "#{Mina.project_name}-staging-tfstate"
  end

  def self.assets_bucket_name
    "#{Mina.project_name}-staging-assets"
  end

  def self.private_key_file_name
    "#{Rails.application.class.module_parent_name.downcase}-staging"
  end

  def self.tf_init
    system "#{tf_setup} init"
  end

  def self.tf_apply
    system "#{tf_setup} apply -auto-approve"
  end

  def self.tf_destroy
    puts "Destroy TF infrastructure"
    system "#{tf_setup} destroy -auto-approve"
    puts "Destroyed TF infrastructure"
    puts "#########################"
  end

  def self.tf_push_error_state
    system "#{tf_setup} state push errored.tfstate"
  end

  def self.empty_s3_bucket bucket_name
    puts "Emptying #{bucket_name} s3 bucket"
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
      puts "#{bucket_name} bucket already emptied"
    rescue Aws::S3::Errors::NoSuchBucket
      puts "#{bucket_name} bucket already destroyed"
    end
    puts "#########################"
  end

  private

  def self.tf_setup
    "cd #{Rails.root.join('terraform', 'staging')} && \
      docker run \
      --rm \
      --env AWS_ACCESS_KEY_ID=#{`aws --profile #{AWS_PROFILE} configure get aws_access_key_id`.chomp} \
      --env AWS_SECRET_ACCESS_KEY=#{`aws --profile #{AWS_PROFILE} configure get aws_secret_access_key`.chomp} \
      --env AWS_DEFAULT_REGION=#{REGION} \
      -v #{Rails.root.join('terraform', 'staging')}:/workspace \
      -w /workspace \
      -it \
      hashicorp/terraform:0.12.12 "
  end
end

namespace :mina do
  desc 'Provision staging server for mina deployment'
  task provision: :environment do
    options = { bucket: Mina.tf_bucket_name }

    begin
      Mina.s3_client.head_bucket(options) # will check and throw error if bucket is not present
      Mina.s3_client.list_buckets.buckets.find { |bucket| bucket.name == Mina.tf_bucket_name }
      puts "#{Mina.tf_bucket_name} already created"
    rescue Aws::S3::Errors::NotFound
      unless Mina::REGION == 'us-east-1'
        options[:create_bucket_configuration] = {}
        options[:create_bucket_configuration][:location_constraint] = Mina::REGION
      end
      bucket = Mina.s3_client.create_bucket(options)
      puts "#{Mina.tf_bucket_name} bucket created successfully"
    end

    FileUtils.mkdir_p(Rails.root.join('terraform', 'staging'))

    puts "Creating private key"
    filepath = "#{Rails.root}/#{Mina.private_key_file_name}"
    if File.exist? filepath
      puts 'Private key already created'
    else
      `ssh-keygen -t rsa -f #{filepath} -C #{Mina.private_key_file_name} -N ''`
      puts 'chmod 400 private and public keys for staging'
      `chmod 400 #{filepath}`
      `chmod 400 #{filepath}.pub`
    end

    file = File.open(Rails.root.join('terraform', 'staging', 'keypair.tf'), 'w')
    file.puts <<~MSG
      resource "aws_key_pair" "main" {
        key_name = "${var.project_name}-${var.env}"
        public_key = "#{`cat #{filepath}.pub`.chomp}"
      }
    MSG
    file.close
    puts "Created private key"
    puts "################"
    puts "Creating setup.tf"
    file = File.open(Rails.root.join('terraform', 'staging', 'setup.tf'), 'w')
    file.puts <<~MSG
      # download all necessary plugins for terraform
      # set versions
      provider "aws" {
        version = "~> 2.24"
        region = "#{Mina::REGION}"
      }

      terraform {
        required_version = "~> 0.12.0"
        backend "s3" {
          bucket = "#{Mina.tf_bucket_name}"
          key = "terraform.tfstate"
          region = "#{Mina::REGION}"
        }
      }

      provider "null" {
        version = "~> 2.1"
      }

    MSG
    file.close
    puts "Created setup.tf"
    puts "################"
    puts "Creating variables.tf"
    file = File.open(Rails.root.join('terraform', 'staging', 'variables.tf'), 'w')
    file.puts <<~MSG
      variable "project_name" {
        type = string
        default = "#{Mina.project_name}"
      }

      variable "region" {
        type = string
        default = "#{Mina::REGION}"
      }

      variable "env" {
        type = string
        default = "staging"
      }
    MSG
    file.close
    puts "Created variables.tf"
    puts "################"
    puts "Creating ec2.tf"
    
    resp = Mina.ec2_client.describe_availability_zones(
      filters: [
        {
          name: 'region-name',
          values: [Mina::REGION]
        }
      ]
    )

    ami = Mina.ec2_client.describe_images(
      filters: [
        {
          name: 'name',
          values: ['amzn2-ami-hvm-2.0.????????.?-x86_64-gp2']
        }
      ],
      owners: ['amazon']
    ).images.max_by(&:creation_date) # latest image

    file = File.open(Rails.root.join('terraform', 'staging', 'ec2.tf'), 'w')

    file.puts <<~MSG
      # Security Groups
      resource "aws_security_group" "staging_web_server" {
        name = "${var.project_name}${var.env}"
        description = "For web servers ${var.env}"

        tags = {
          Name = "${var.project_name}${var.env}"
        }
      }

      resource "aws_security_group_rule" "ssh-world-staging_web_server" {
        type = "ingress"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        security_group_id = aws_security_group.staging_web_server.id
        cidr_blocks = ["0.0.0.0/0"]
      }

      resource "aws_instance" "staging_web_server" {
        ami = "#{ami.image_id}"
        associate_public_ip_address = true
        instance_type = "t2.micro"
        key_name = aws_key_pair.main.key_name

        tags = {
          Name = "staging_web_server-${var.project_name}${var.env}"
        }
      }

      output "server_public_ip" {
        value = aws_instance.staging_web_server.public_ip
      }
    MSG
    file.close
    puts "Created ec2.tf"
    puts "################"
    puts "Creating assets.tf"
    # S3FullAccess full policy referenced from
    # https://bl.ocks.org/magnetikonline/6215d9e80021c1f8de12#full-access-for-specific-iam-userrole
    file = File.open(Rails.root.join('terraform', 'staging', 'assets_bucket_policy.tmpl'), 'w')
    file.puts <<~MSG
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Action": [
              "s3:ListAllMyBuckets"
            ],
            "Effect": "Allow",
            "Resource": [
              "arn:aws:s3:::*"
            ]
          },
          {
            "Action": [
              "s3:*"
            ],
            "Effect": "Allow",
            "Resource": [
              "arn:aws:s3:::${bucket_name}/*"
            ]
          }
        ]
      }
    MSG
    file.close
    file = File.open(Rails.root.join('terraform', 'staging', 'assets.tf'), 'w')
    file.puts <<~MSG
      resource "aws_s3_bucket" "assets" {
        bucket = "#{Mina.assets_bucket_name}"
        region = "#{Mina::REGION}"

        cors_rule {
          allowed_headers = ["*"]
          allowed_methods = ["GET", "HEAD"]
          allowed_origins = ["*"]
        }

        tags = {
          Name = var.project_name
          Env = var.env
        }
      }

      module "assets-iam_policy" {
        source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
        version = "~> 2.0"

        name = "assets-policy-${var.project_name}${var.env}"
        description = "Assets bucket policy for ${var.project_name}-${var.env}"

        policy = templatefile("${path.module}/assets_bucket_policy.tmpl", { bucket_name = aws_s3_bucket.assets.id })
      }

      module "assets-iam_user" {
        source  = "terraform-aws-modules/iam/aws//modules/iam-user"
        version = "~> 2.0"

        create_iam_access_key = "true"
        create_iam_user_login_profile = "false"

        name = "assets-${var.project_name}${var.env}"

        tags = {
          Name = "assets-${var.project_name}${var.env}"
        }
      }

      resource "aws_iam_user_policy_attachment" "assets" {
        user = module.assets-iam_user.this_iam_user_name
        policy_arn = module.assets-iam_policy.arn
      }

      output "assets-user-access_key_id" {
        value = module.assets-iam_user.this_iam_access_key_id
      }

      output "assets-user-secret_access_key" {
        value = module.assets-iam_user.this_iam_access_key_secret
      }

      output "assets-bucket_name" {
        value = aws_s3_bucket.assets.id
      }
    MSG
    file.close
    puts "Created assets.tf"
    puts "################"
    puts "Run Terraform"
    Mina.tf_init
    Mina.tf_apply
  end

  desc 'Remove staging server meant for mina deployment'
  task destroy: :environment do
    s3_client = Mina.s3_client

    Mina.empty_s3_bucket(Mina.assets_bucket_name)
    Mina.tf_destroy
    Mina.empty_s3_bucket(Mina.tf_bucket_name)

    options = { bucket: Mina.tf_bucket_name }
    begin
      Mina.s3_client.head_bucket(options) # will check and throw error if bucket is not present
      Mina.s3_client.delete_bucket(options)
      puts "#{Mina.tf_bucket_name} bucket deleted successfully"
    rescue Aws::S3::Errors::NotFound
      puts "#{Mina.tf_bucket_name} bucket already deleted"
    end

    FileUtils.rm_rf(Rails.root.join('terraform', 'staging'))
  end
end

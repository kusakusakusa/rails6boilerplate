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

  def self.project_name
    Rails.application.class.module_parent_name.downcase
  end

  def self.tf_bucket_name
    "#{Mina.project_name}-staging-tfstate"
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
  end

  desc 'Remove staging server meant for mina deployment'
  task destroy: :environment do
    s3_client = Mina.s3_client

    options = { bucket: Mina.tf_bucket_name }

    begin
      Mina.s3_client.head_bucket(options) # will check and throw error if bucket is not present
      Mina.s3_client.delete_bucket(options)
      puts "#{Mina.tf_bucket_name} bucket deleted successfully"
    rescue Aws::S3::Errors::NotFound
      puts "#{Mina.tf_bucket_name} bucket already deleted"
    end
  end
end

# frozen_string_literal: true

namespace :packer do
  desc 'Create ec2.json'
  task :create_ec2_json, [:aws_profile, :env, :region] => :environment do |task, args|
    puts "START - Create ec2.json for #{args[:env]}"
    ami = `aws ec2  describe-images --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-????????' 'Name=state,Values=available' --profile #{args[:aws_profile]} --region #{args[:region]} --output json | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId'`.chomp
    file = File.open(Rails.root.join('terraform', args[:env], 'ec2.json'), 'w')
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
            "source_ami": "#{ami}",
            "instance_type": "t2.micro",
            "ssh_username": "ubuntu",
            "ami_name": "{{user `project_name`}}-{{user `env`}}",
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
            "scripts": [
              "packages_installation.sh",
              "yarn_installation.sh",
              "rvm_installation.sh",
              "swap_installation.sh",
              "mysql_installation.sh",
              "logrotate.sh"
            ]
          }
        ]
      }
    MSG
    file.close
    puts "END - Create ec2.json for #{args[:env]}"
  end
end
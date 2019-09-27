#!/usr/bin/env bash

echo 'Install packages'
sudo apt-get -y update
sudo apt-get update -y && sudo apt-get upgrade -y && sudo apt-get install nginx gnupg2 nodejs build-essential mysql-server libmysqlclient-dev awscli npm sendmail -y
#!/usr/bin/env bash

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

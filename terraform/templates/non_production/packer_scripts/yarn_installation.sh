#!/usr/bin/env bash

echo 'Install yarn via npm'
sudo npm install -g yarn
if [ $? -ne 0 ]
then
  echo 'Fail to install npm'
  exit 1
fi
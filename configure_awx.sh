#!/bin/bash

set -e 

apt update
apt-get -y upgrade
# Install Ansible
apt -y install software-properties-common
apt-add-repository --yes --update ppa:ansible/ansible
apt -y install ansible

# Install Make (https://help.ubuntu.com/community/InstallingCompilers)
apt-get -y install build-essential

# Install Node 10.x and NPM 6.X (https://www.digitalocean.com/community/tutorials/how-to-install-node-js-on-ubuntu-18-04)
cd ~
curl -sL https://deb.nodesource.com/setup_10.x -o nodesource_setup.sh
/bin/bash nodesource_setup.sh
apt -y install nodejs
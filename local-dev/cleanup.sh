#!/bin/bash

set -e  # Exit on error

# Stop all installed services
sudo systemctl stop jenkins nginx docker || true
sudo systemctl disable jenkins nginx docker || true

# Purge all installed packages
sudo apt-get purge -y jenkins nginx docker.io openjdk-17-jdk
sudo apt-get autoremove -y
sudo apt-get autoclean

# Delete data and configuration directories
sudo rm -rf /var/lib/jenkins
sudo rm -rf /etc/jenkins
sudo rm -rf /etc/nginx
sudo rm -rf /var/lib/docker
sudo rm -rf /etc/docker

# Systemd overrides
sudo rm -rf /etc/systemd/system/jenkins.service.d/

# APT Repository lists and keys
sudo rm -f /etc/apt/sources.list.d/jenkins.list
sudo rm -f /usr/share/keyrings/jenkins-keyring.asc

# Remove known_hosts and reset SSH trust
sudo rm -f /root/.ssh/known_hosts
sudo rm -f /home/ubuntu/.ssh/known_hosts
sudo rm -rf /tmp/jenkins*

# Kill any stray SSH agents
sudo pkill ssh-agent || true

# Forcefully remove the jenkins user if it still exists
sudo deluser --remove-home jenkins || true
sudo delgroup jenkins || true

# Final system refresh
sudo systemctl daemon-reload
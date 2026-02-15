#!/bin/bash
set -e 

# stops the apps
sudo systemctl stop jenkins nginx docker || true
sudo systemctl disable jenkins nginx docker || true

# clear for any stuck docker mounts before the purge
if [ -d "/var/lib/docker" ]; then
    sudo findmnt -n -o TARGET -S /var/lib/docker | xargs -r sudo umount || true
fi

# purge packages
sudo apt-get purge -y jenkins nginx nginx-common nginx-full docker.io openjdk-17-jdk
sudo apt-get autoremove -y
sudo apt-get autoclean

# delete all data, logs and config
sudo rm -rf /var/lib/jenkins
sudo rm -rf /var/log/jenkins
sudo rm -rf /etc/jenkins
sudo rm -rf /etc/nginx
sudo rm -rf /var/log/nginx
sudo rm -rf /var/lib/docker
sudo rm -rf /etc/docker
sudo rm -rf /etc/systemd/system/jenkins.service.d/

#  cleanup keys and repos
sudo rm -f /etc/apt/sources.list.d/jenkins.list
sudo rm -f /usr/share/keyrings/jenkins-keyring.asc

# reset ssh and temp files
sudo rm -f /root/.ssh/known_hosts
sudo rm -f /home/ubuntu/.ssh/known_hosts
sudo rm -rf /tmp/jenkins*
sudo pkill ssh-agent || true

# user and group clean up
sudo deluser --remove-home jenkins || true
sudo delgroup jenkins || true
sudo delgroup docker || true

# system refresh
sudo systemctl daemon-reload
sudo apt update -y
#!/bin/bash

set -euo pipefail

# =========================================
# Jenkins Full Setup Script for Ubuntu 22.04+
# =========================================

echo "=== Updating system packages ==="
sudo apt update -y
sudo apt upgrade -y

echo "=== Installing essential packages ==="
sudo apt install -y openjdk-17-jdk docker.io nginx git curl gnupg openssl

echo "=== Verifying Java installation ==="
java -version

echo "=== Creating keyrings directory ==="
sudo mkdir -p /etc/apt/keyrings

echo "=== Adding Jenkins GPG key ==="
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
    | sudo tee /etc/apt/keyrings/jenkins-keyring.asc > /dev/null

echo "=== Adding Jenkins repository ==="
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
    | sudo tee /etc/apt/sources.list.d/jenkins.list

echo "=== Updating package lists after adding Jenkins repo ==="
sudo apt update

echo "=== Installing Jenkins ==="
sudo apt install -y jenkins

echo "=== Starting and enabling Jenkins service ==="
sudo systemctl start jenkins
sudo systemctl enable jenkins

echo "=== Verifying Jenkins service status ==="
sudo systemctl status jenkins --no-pager

echo "=== Setup complete ==="
echo "Access Jenkins UI at: http://<VM-IP>:8080"
echo "Retrieve initial admin password with:"
echo "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"

echo "=== Optional: Open firewall port 8080 if using UFW ==="
echo "sudo ufw allow 8080/tcp"

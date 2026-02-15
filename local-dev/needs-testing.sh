#!/bin/bash

set -euo pipefail

# 0. Silence the "Kernel Upgrade" prompts
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

echo "=== Updating system packages ==="
sudo apt update -y
sudo apt upgrade -y

echo "=== Installing essential packages ==="
sudo apt install -y openjdk-17-jdk docker.io nginx git curl gnupg openssl

# --- 1. FIXED JENKINS REPO SETUP ---
echo "=== Adding Jenkins GPG key and Repository ==="
sudo mkdir -p /usr/share/keyrings
# Download and de-armor the key so it's in a format apt always understands
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
    gpg --dearmor | sudo tee /usr/share/keyrings/jenkins-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" | \
    sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update
sudo apt install -y jenkins

# --- 2. PLUGIN INSTALLATION (No-UI Requirement) ---
echo "=== Installing JCasC and JobDSL Plugins ==="
curl -L "https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.13.0/jenkins-plugin-manager-2.13.0.jar" -o jenkins-plugin-manager.jar
sudo java -jar jenkins-plugin-manager.jar --war /usr/share/java/jenkins.war --plugin-download-directory /var/lib/jenkins/plugins --plugins configuration-as-code job-dsl docker-workflow git
sudo chown -R jenkins:jenkins /var/lib/jenkins/plugins

# --- 3. JCasC & SYSTEMD OVERRIDE ---
echo "=== Configuring JCasC Pathing ==="
sudo mkdir -p /var/lib/jenkins/casc/
# Use the file from your repo clone
if [ -f "./jenkins.yaml" ]; then
    sudo cp ./jenkins.yaml /var/lib/jenkins/casc/
    sudo chown -R jenkins:jenkins /var/lib/jenkins/casc/
fi

sudo mkdir -p /etc/systemd/system/jenkins.service.d/
sudo tee /etc/systemd/system/jenkins.service.d/override.conf <<EOF
[Service]
Environment="CASC_JENKINS_CONFIG=/var/lib/jenkins/casc/jenkins.yaml"
# This injects your .env variables into Jenkins
$(grep -v '^#' ./jenkins.env | sed 's/^/Environment="/; s/$/"/')
EOF

# --- 4. SSL & NGINX PROXY ---
echo "=== Setting up Nginx for the Node App (443) ==="
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/app.key \
    -out /etc/nginx/ssl/app.crt \
    -subj "/C=US/ST=State/L=City/O=Org/CN=node-app.local"

sudo tee /etc/nginx/conf.d/node_app.conf <<EOF
server {
    listen 443 ssl;
    ssl_certificate /etc/nginx/ssl/app.crt;
    ssl_certificate_key /etc/nginx/ssl/app.key;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo rm -f /etc/nginx/sites-enabled/default

# --- 5. RESTART & VERIFY ---
sudo usermod -aG docker jenkins
sudo systemctl daemon-reload
sudo systemctl restart jenkins nginx docker
sudo systemctl enable jenkins nginx docker

echo "=== Final Status Check ==="
sudo systemctl status jenkins --no-pager
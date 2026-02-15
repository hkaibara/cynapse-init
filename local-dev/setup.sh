#!/bin/bash

set -euo pipefail

# initial update/upgrades
sudo apt update -y
sudo apt upgrade -y

# install necessary packages
sudo apt install -y openjdk-17-jdk docker.io nginx git curl gnupg openssl rsync xz-utils tar

# jenkins repo setup
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# update again then install jenkins
sudo apt update
sudo apt install -y jenkins

# stop jenkins for now to avoid race conditions with plugins
sudo systemctl stop jenkins

# install jenkins plugins
PLUGIN_DIR="/var/lib/jenkins/plugins"
sudo mkdir -p "$PLUGIN_DIR"
PLUGIN_MANAGER_JAR="jenkins-plugin-manager.jar"
if [ ! -f "$PLUGIN_MANAGER_JAR" ]; then
    curl -L "https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.13.0/jenkins-plugin-manager-2.13.0.jar" -o "$PLUGIN_MANAGER_JAR"
fi

# place the necessary plugins into these env.
PLUGINS="configuration-as-code ssh-credentials git matrix-auth workflow-aggregator job-dsl nodejs"

# downloads jenkins plugins and their dependencies, and then ensure compatibility with the installed WAR version
sudo java -jar "$PLUGIN_MANAGER_JAR" --war /usr/share/java/jenkins.war --plugin-download-directory "$PLUGIN_DIR" --plugins $PLUGINS

# config section for jenkins' JCasC, ssh keys and systemd override
# sshkey section
if [ -f "./id_rsa" ]; then
    sudo mkdir -p /var/lib/jenkins/.ssh
    sudo cp ./id_rsa /var/lib/jenkins/.ssh/id_rsa
    sudo sed -i 's/\r$//' /var/lib/jenkins/.ssh/id_rsa
    sudo chmod 600 /var/lib/jenkins/.ssh/id_rsa
fi
# JCasC section
JENKINS_CASC_DIR="/var/lib/jenkins/casc"
sudo mkdir -p "$JENKINS_CASC_DIR"
if [ -f "./jenkins.yaml" ]; then
    sudo cp ./jenkins.yaml "$JENKINS_CASC_DIR/"
fi

# systemd section
sudo mkdir -p /etc/systemd/system/jenkins.service.d/
sudo tee /etc/systemd/system/jenkins.service.d/override.conf <<EOF
[Service]
Environment="JENKINS_HOME=/var/lib/jenkins"
Environment="CASC_JENKINS_CONFIG=$JENKINS_CASC_DIR/jenkins.yaml"
$(grep -v '^#' ./jenkins.env | sed 's/^/Environment="/; s/$/"/')
EOF

# SSL and nginx proxy setup
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/app.key \
    -out /etc/nginx/ssl/app.crt \
    -subj "/C=US/ST=State/L=City/O=Org/CN=node-app.local"

# nginx config.d
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

# --- 5. FINAL SETUP & SERVICE MANAGEMENT ---
echo "=== Finalizing Permissions and Starting Services ==="

# just a bit of cleanup when script has been rerun
sudo rm -rf /var/lib/jenkins/.jenkins
sudo chown -R jenkins:jenkins /var/lib/jenkins

# grant jenkins permission to docker
sudo usermod -aG docker jenkins
sudo systemctl daemon-reload
sudo systemctl restart jenkins nginx docker
# add apps to auto run when vm boots up
sudo systemctl enable jenkins nginx docker

# just to see things much better if script run smoothly or with errors
sudo systemctl status jenkins --no-pager
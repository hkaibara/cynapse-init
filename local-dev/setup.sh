#!/bin/bash

set -euo pipefail

# 0. Silence the "Kernel Upgrade" prompts
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

echo "=== Updating system packages ==="
sudo apt update -y
sudo apt upgrade -y

echo "=== Installing essential packages ==="
sudo apt install -y openjdk-17-jdk docker.io nginx git curl gnupg openssl rsync

# --- 1. FIXED JENKINS REPO SETUP ---
echo "=== Adding Jenkins GPG key and Repository ==="
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update
sudo apt install -y jenkins

### CHANGE: Stop Jenkins immediately after install to prevent race conditions 
### during plugin/config injection.
sudo systemctl stop jenkins

# --- 2. PLUGIN INSTALLATION (No-UI Requirement) ---
echo "=== Installing Jenkins Plugins ==="
PLUGIN_DIR="/var/lib/jenkins/plugins"
sudo mkdir -p "$PLUGIN_DIR"
PLUGIN_MANAGER_JAR="jenkins-plugin-manager.jar"

if [ ! -f "$PLUGIN_MANAGER_JAR" ]; then
    curl -L "https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.13.0/jenkins-plugin-manager-2.13.0.jar" -o "$PLUGIN_MANAGER_JAR"
fi

# List all required plugins
PLUGINS="configuration-as-code ssh-credentials git matrix-auth workflow-aggregator job-dsl"

sudo java -jar "$PLUGIN_MANAGER_JAR" \
    --war /usr/share/java/jenkins.war \
    --plugin-download-directory "$PLUGIN_DIR" \
    --plugins $PLUGINS

# --- 3. JCasC, SSH KEYS & SYSTEMD OVERRIDE ---
echo "=== Configuring SSH Keys and JCasC ==="

if [ -f "./id_rsa" ]; then
    sudo mkdir -p /var/lib/jenkins/.ssh
    sudo cp ./id_rsa /var/lib/jenkins/.ssh/id_rsa
    sudo sed -i 's/\r$//' /var/lib/jenkins/.ssh/id_rsa
    sudo chmod 600 /var/lib/jenkins/.ssh/id_rsa
fi

JENKINS_CASC_DIR="/var/lib/jenkins/casc"
sudo mkdir -p "$JENKINS_CASC_DIR"
if [ -f "./jenkins.yaml" ]; then
    sudo cp ./jenkins.yaml "$JENKINS_CASC_DIR/"
fi

### CHANGE: Explicitly define JENKINS_HOME in the override. 
### This prevents Jenkins from creating the hidden ".jenkins" folder.
sudo mkdir -p /etc/systemd/system/jenkins.service.d/
sudo tee /etc/systemd/system/jenkins.service.d/override.conf <<EOF
[Service]
Environment="JENKINS_HOME=/var/lib/jenkins"
Environment="CASC_JENKINS_CONFIG=$JENKINS_CASC_DIR/jenkins.yaml"
$(grep -v '^#' ./jenkins.env | sed 's/^/Environment="/; s/$/"/')
EOF

### CHANGE: Force-disable the Setup Wizard via Groovy script.
### This ensures Jenkins boots straight into JCasC mode without waiting for a UI login.
sudo mkdir -p /var/lib/jenkins/init.groovy.d
echo 'jenkins.install.InstallState.initializeDefault()' | sudo tee /var/lib/jenkins/init.groovy.d/skip-wizard.groovy

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

# --- 5. FINAL SETUP & SERVICE MANAGEMENT ---
echo "=== Finalizing Permissions and Starting Services ==="

### CHANGE: Heavy-duty permission fix and cleanup of the "hidden" home directory
### to ensure no conflicting data exists before the first clean boot.
sudo rm -rf /var/lib/jenkins/.jenkins
sudo chown -R jenkins:jenkins /var/lib/jenkins

sudo usermod -aG docker jenkins
sudo systemctl daemon-reload
sudo systemctl restart jenkins nginx docker
sudo systemctl enable jenkins nginx docker

echo "=== Final Status Check ==="
sudo systemctl status jenkins --no-pager
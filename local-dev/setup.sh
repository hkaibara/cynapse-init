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
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update
sudo apt install -y jenkins

# --- 2. PLUGIN INSTALLATION (No-UI Requirement) ---
echo "=== Installing Jenkins Plugins ==="
PLUGIN_DIR="/var/lib/jenkins/plugins"
sudo mkdir -p "$PLUGIN_DIR"
PLUGIN_MANAGER_JAR="jenkins-plugin-manager.jar"

if [ ! -f "$PLUGIN_MANAGER_JAR" ]; then
    curl -L "https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.13.0/jenkins-plugin-manager-2.13.0.jar" -o "$PLUGIN_MANAGER_JAR"
fi

# List all required plugins (Crucial: ssh-credentials must be here for JCasC to work)
PLUGINS="configuration-as-code ssh-credentials git matrix-auth workflow-aggregator job-dsl"

sudo java -jar "$PLUGIN_MANAGER_JAR" \
    --war /usr/share/java/jenkins.war \
    --plugin-download-directory "$PLUGIN_DIR" \
    --plugins $PLUGINS

sudo chown -R jenkins:jenkins "$PLUGIN_DIR"

# --- 3. JCasC, SSH KEYS & SYSTEMD OVERRIDE ---
echo "=== Configuring SSH Keys and JCasC ==="

# Fix the libcrypto error by sanitizing the SSH key before copying
if [ -f "./id_rsa" ]; then
    sudo mkdir -p /var/lib/jenkins/.ssh
    sudo cp ./id_rsa /var/lib/jenkins/.ssh/id_rsa
    # REMOVE WINDOWS LINE ENDINGS (The \r fix)
    sudo sed -i 's/\r$//' /var/lib/jenkins/.ssh/id_rsa
    sudo chmod 600 /var/lib/jenkins/.ssh/id_rsa
    sudo chown -R jenkins:jenkins /var/lib/jenkins/.ssh
fi

JENKINS_CASC_DIR="/var/lib/jenkins/casc"
sudo mkdir -p "$JENKINS_CASC_DIR"
if [ -f "./jenkins.yaml" ]; then
    sudo cp ./jenkins.yaml "$JENKINS_CASC_DIR/"
    sudo chown -R jenkins:jenkins "$JENKINS_CASC_DIR"
fi

sudo mkdir -p /etc/systemd/system/jenkins.service.d/
sudo tee /etc/systemd/system/jenkins.service.d/override.conf <<EOF
[Service]
Environment="CASC_JENKINS_CONFIG=$JENKINS_CASC_DIR/jenkins.yaml"
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

# --- 5. FINAL SETUP & SERVICE MANAGEMENT ---
echo "=== Adding Jenkins to Docker group & Restarting Services ==="
# Fix permissions for the entire home directory to be safe
sudo chown -R jenkins:jenkins /var/lib/jenkins

sudo usermod -aG docker jenkins
sudo systemctl daemon-reload
sudo systemctl restart jenkins nginx docker
sudo systemctl enable jenkins nginx docker

echo "=== Final Status Check ==="
sudo systemctl status jenkins --no-pager
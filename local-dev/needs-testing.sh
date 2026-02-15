#!/bin/bash

set -euo pipefail

# =========================================================
# 1. SYSTEM, DOCKER & NGINX INSTALLATION
# =========================================================
echo "=== Installing Dependencies, Docker, and Nginx ==="
sudo apt update -y
sudo apt install -y openjdk-17-jdk docker.io nginx git curl gnupg openssl

# Ensure Jenkins user can run Docker commands for the build stage
sudo usermod -aG docker jenkins

# =========================================================
# 2. JENKINS INSTALLATION
# =========================================================
echo "=== Adding Jenkins Repo and Installing Service ==="
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update
sudo apt install -y jenkins

# =========================================================
# 3. AUTOMATED PLUGIN INSTALLATION (The "No-UI" Constraint)
# =========================================================
echo "=== Pre-installing JCasC and JobDSL Plugins ==="
PLUGIN_CLI_URL="https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.13.0/jenkins-plugin-manager-2.13.0.jar"
curl -L $PLUGIN_CLI_URL -o jenkins-plugin-manager.jar

# Install plugins directly to the folder before Jenkins finishes booting
sudo java -jar jenkins-plugin-manager.jar \
    --war /usr/share/java/jenkins.war \
    --plugin-download-directory /var/lib/jenkins/plugins \
    --plugins configuration-as-code job-dsl docker-workflow git

sudo chown -R jenkins:jenkins /var/lib/jenkins/plugins

# =========================================================
# 4. JCasC CONFIGURATION & SYSTEMD OVERRIDE
# =========================================================
echo "=== Setting up Configuration as Code ==="
sudo mkdir -p /var/lib/jenkins/casc/
# Assuming jenkins.yaml is in the same folder as this script
if [ -f "./jenkins.yaml" ]; then
    sudo cp ./jenkins.yaml /var/lib/jenkins/casc/
    sudo chown -R jenkins:jenkins /var/lib/jenkins/casc/
else
    echo "ERROR: jenkins.yaml not found in current directory!"
    exit 1
fi

# Inject the environment variable so Jenkins knows where the YAML is
sudo mkdir -p /etc/systemd/system/jenkins.service.d/
sudo tee /etc/systemd/system/jenkins.service.d/override.conf <<EOF
[Service]
Environment="CASC_JENKINS_CONFIG=/var/lib/jenkins/casc/jenkins.yaml"
EOF

# =========================================================
# 5. OPENSSL & NGINX (HTTPS 443 for Node App)
# =========================================================
echo "=== Generating SSL & Configuring Nginx Proxy ==="
sudo mkdir -p /etc/nginx/ssl

# Generate Self-Signed Certs for the App (Non-interactive)
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/app.key \
    -out /etc/nginx/ssl/app.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=node-app.local"

# Configure Nginx in conf.d for modularity
sudo tee /etc/nginx/conf.d/node_app.conf <<EOF
server {
    listen 443 ssl;
    server_name _;

    ssl_certificate           /etc/nginx/ssl/app.crt;
    ssl_certificate_key       /etc/nginx/ssl/app.key;

    location / {
        proxy_pass http://127.0.0.1:3000; # App runs in Docker on port 3000
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Cleanup default Nginx config
sudo rm -f /etc/nginx/sites-enabled/default

# =========================================================
# 6. START SERVICES
# =========================================================
echo "=== Starting All Services ==="
sudo systemctl daemon-reload
sudo systemctl restart jenkins nginx docker
sudo systemctl enable jenkins nginx docker

echo "=== Setup Complete ==="
echo "Jenkins: http://$(curl -s ifconfig.me):8080"
echo "App (after pipeline runs): https://$(curl -s ifconfig.me)"
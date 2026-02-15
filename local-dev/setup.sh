#!/bin/bash
source jenkins.env
sudo apt-get update && sudo apt-get install -y docker.io nginx openssl openjdk-17-jre wget
sudo mkdir -p /var/lib/jenkins/.ssh
sudo ssh-keygen -t ed25519 -N "" -f /var/lib/jenkins/.ssh/id_ed25519
sudo chown -R jenkins:jenkins /var/lib/jenkins/.ssh
export SSH_PRIVATE_KEY=$(sudo cat /var/lib/jenkins/.ssh/id_ed25519)
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt-get update && sudo apt-get install -y jenkins
sudo usermod -aG docker jenkins
sudo systemctl enable --now jenkins nginx docker
echo "CASC_JENKINS_CONFIG=$CASC_JENKINS_CONFIG" | sudo tee -a /etc/environment
sudo mkdir -p /etc/nginx/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/jenkins.key -out /etc/nginx/ssl/jenkins.crt -subj "/C=US/ST=State/L=City/O=Dev/CN=localhost"
cat <<NGINX | sudo tee /etc/nginx/sites-available/default
server {
    listen 443 ssl;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
    }
}
NGINX
sudo systemctl restart nginx jenkins
echo "Done. Public Key for GitHub:"
sudo cat /var/lib/jenkins/.ssh/id_ed25519.pub

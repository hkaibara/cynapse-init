# Cynapse - Hiroshi Kaibara

Technical assessment for DevOps Role.

## Overview

This is a lightweight Express.js web application that serves a simple greeting message. The project showcases:
- Node.js development with Express
- Containerization with Docker multi-stage builds
- Automated CI/CD 
- Jenkins Configuration as Code (JCasC)
- Automated rollback on deployment failures

## Prerequisites

### System Requirements
- Linux-based system
- Docker
- Jenkins (installed via setup script)
- Git
- Node.js 20.x (for local development)

### Initial Environment Setup

Before setting up the application, you need to prepare your environment:

#### 1. Install Git
```bash
sudo apt update && sudo apt install -y git
```

#### 2. Create Jenkins User and Group
```bash
sudo groupadd -g 1001 jenkins
sudo useradd -u 1001 -g jenkins -m -d /var/lib/jenkins -s /bin/bash jenkins
```

#### 3. Generate SSH Keys for Jenkins
```bash
sudo -u jenkins ssh-keygen -t rsa -b 4096 -f /var/lib/jenkins/.ssh/id_rsa -N ""
```

#### 4. Display Public Key (Add this to your GitHub account)
```bash
sudo cat /var/lib/jenkins/.ssh/id_rsa.pub
```

**Important**: Copy the output and add it as a deploy key in your GitHub repository settings:
- Go to your repository on GitHub
- Navigate to Settings → Deploy keys → Add deploy key
- Paste the public key and grant read access (write access if needed)

#### 5. Add GitHub to Known Hosts
```bash
sudo -u jenkins ssh-keyscan github.com | sudo tee -a /var/lib/jenkins/.ssh/known_hosts
```

#### 6. Clone the Repository
```bash
sudo -u jenkins git clone git@github.com:hkaibara/cynapse-init.git /tmp/jenkins-bootstrap
```

#### 7. Run Setup Script
```bash
cd /tmp/jenkins-bootstrap/local-dev/
sudo sed -i 's/\r$//' setup.sh 
sudo chmod +x setup.sh 
sudo ./setup.sh
```

The setup script will automatically install and configure:
- Docker
- Jenkins with necessary plugins
- Required dependencies

## Architecture

### Application Structure
```
cynapse-init/
├── index.js              # Main Express application
├── package.json          # Node.js dependencies and scripts
├── dockerfile            # Multi-stage Docker build configuration
├── Jenkinsfile           # Jenkins pipeline definition
├── app.json              # Application metadata
├── public/               # Static files directory
└── local-dev/            # Local development setup scripts
    ├── setup.sh          # Automated installation script
    ├── jenkins.yaml      # Jenkins Configuration as Code (JCasC)
    └── jenkins.env       # Jenkins environment variables (repository config)
```

### How It Works

#### Application Layer
The application is a minimal Express.js server that:
1. Listens on port 5000 (configurable via `PORT` environment variable)
2. Serves static files from the `/public` directory
3. Responds with "Candidate Name: Hiroshi Kaibara" on the root path (`/`)

#### Docker Layer
The Dockerfile uses a multi-stage build approach:
1. **Builder Stage**: Uses `node:20-slim` to install dependencies with `npm ci`
2. **Runtime Stage**: Copies only necessary files (node_modules and app code)
3. **Result**: Optimized, smaller image size with better security

#### CI/CD Pipeline
The Jenkins pipeline automates the entire deployment workflow:

**Stage 1: Initialization**
- Captures the current running Docker image as a reference
- Stores this as `PREVIOUS_STABLE` for potential rollback

**Stage 2: Build Docker**
- Tags the current `latest` image as `backup` (if exists)
- Builds a fresh Docker image with `--no-cache` flag
- Cleans up dangling images to save disk space

**Stage 3: Deploy**
- Stops and removes the existing container
- Launches a new container with the newly built image
- Maps port 5000 from container to host

**Post-Build: Automatic Rollback**
- If any stage fails, automatically reverts to the `backup` image
- Ensures minimal downtime and service continuity

## Local Development Setup

### Option 1: Node.js (Direct)

1. **Clone the repository**:
```bash
git clone git@github.com:hkaibara/cynapse-init.git
cd cynapse-init
```

2. **Install dependencies**:
```bash
npm install
```

3. **Run the application**:
```bash
npm start
```

4. **Access the application**:
Open your browser and navigate to `http://localhost:5000`

### Option 2: Docker (Recommended)

1. **Build the Docker image**:
```bash
docker build -t cynapse-init .
```

2. **Run the container**:
```bash
docker run -d -p 5000:5000 --name cynapse-app cynapse-init
```

3. **View logs**:
```bash
docker logs cynapse-app
```

4. **Access the application**:
Open your browser and navigate to `http://localhost:5000`

## Jenkins Deployment

### Automated Configuration with JCasC

The Jenkins setup is fully automated using Jenkins Configuration as Code (JCasC). When you run the `setup.sh` script, Jenkins is automatically configured with:

- **Pipeline Jobs**: Pre-configured from `local-dev/jenkins.yaml`
- **Repository Configuration**: Set in `local-dev/jenkins.env`
- **Credentials**: Automatically configured SSH keys
- **Plugins**: All necessary plugins installed
- **Security Settings**: Basic security configuration

### Configuration Files

**`local-dev/jenkins.yaml`**
- Contains the complete Jenkins Configuration as Code
- Defines pipeline jobs, credentials, and system settings
- Automatically applied on Jenkins startup

**`local-dev/jenkins.env`**
- Sets the application repository URL

### Accessing Jenkins

1. **After running the setup script**, Jenkins will be available at:
   ```
   http://your-server-ip:8080
   ```

2. **Initial Credentials are set  within the jenkins.yaml, please make sure to change the password upon login if exposed publicly.**   

3. **Login and verify configuration**:
   - The pipeline job should already be created
   - Repository should be configured from `jenkins.env`

### Running the Pipeline

The pipeline is automatically configured and ready to use:

1. Navigate to the Jenkins dashboard
2. Click on the pipeline job (name defined in `jenkins.yaml`)
3. Click "Build Now"
4. Monitor the build progress in the console output

### Pipeline Workflow

The automated pipeline executes three stages:

**Stage 1: Initialization**
- Captures the current running Docker image
- Stores reference for potential rollback

**Stage 2: Build Docker**
- Tags current image as backup
- Builds fresh Docker image with `--no-cache`
- Cleans up dangling images

**Stage 3: Deploy**
- Stops and removes existing container
- Launches new container with updated image
- Maps port 5000 to host

**Automatic Rollback**
- If any stage fails, reverts to backup image
- Ensures zero-downtime deployment

### Modifying Configuration

To update the Jenkins configuration:

1. **Edit repository settings**:
   ```bash
   nano /tmp/jenkins-bootstrap/local-dev/jenkins.env
   ```

2. **Edit Jenkins configuration**:
   ```bash
   nano /tmp/jenkins-bootstrap/local-dev/jenkins.yaml
   ```

3. **Restart Jenkins to apply changes**:
   ```bash
   sudo systemctl restart jenkins
   ```



## Cleanup

### Stop and Remove Local Docker Container
```bash
docker stop cynapse-app
docker rm cynapse-app
```

### Remove Docker Images
```bash
# Remove specific image
docker rmi cynapse-init

# Remove all related images (including backup)
docker rmi my-node-app:latest my-node-app:backup

# Clean up dangling images
docker image prune -f
```

### Stop Jenkins Pipeline Container
If Jenkins is running in Docker:
```bash
docker stop node-app-container
docker rm node-app-container
```

### Remove Jenkins User and Files
```bash
# Stop Jenkins service first
sudo systemctl stop jenkins

# Remove Jenkins user
sudo userdel -r jenkins

# Remove Jenkins group
sudo groupdel jenkins

# Remove temporary files
sudo rm -rf /tmp/jenkins-bootstrap
```

### Complete System Cleanup
To remove all Docker resources and Jenkins:
```bash
# Stop all containers
docker stop $(docker ps -aq)

# Remove all containers
docker rm $(docker ps -aq)

# Remove all images
docker rmi $(docker images -q)

# Remove all volumes
docker volume prune -f

# Remove all networks
docker network prune -f

# Uninstall Jenkins (Ubuntu/Debian)
sudo apt remove --purge jenkins -y
sudo apt autoremove -y
```

## Troubleshooting

### Port Already in Use
If port 5000 is already in use:
```bash
# Find process using port 5000
lsof -i :5000

# Kill the process
kill -9 <PID>

# Or use a different port
PORT=3000 npm start
```

### Docker Build Fails
```bash
# Clear Docker cache
docker builder prune -a

# Rebuild without cache
docker build --no-cache -t cynapse-init .
```

### Jenkins Pipeline Fails
1. Check Jenkins console output for error messages
2. Verify Docker is running: `docker ps`
3. Check Docker logs: `docker logs node-app-container`
4. Ensure Jenkins user has Docker permissions:
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### SSH Key Issues with GitHub
```bash
# Test SSH connection
sudo -u jenkins ssh -T git@github.com

# If fails, regenerate and re-add SSH key
sudo -u jenkins ssh-keygen -t rsa -b 4096 -f /var/lib/jenkins/.ssh/id_rsa -N "" -y
sudo cat /var/lib/jenkins/.ssh/id_rsa.pub
```

### Container Won't Start
```bash
# Check container logs
docker logs node-app-container

# Inspect container
docker inspect node-app-container

# Check if port is available
netstat -tuln | grep 5000
```

## Testing

### Health Check
```bash
# Check if application is responding
curl http://localhost:5000

# Expected output:
# Candidate Name: Hiroshi Kaibara
```

### Docker Container Health
```bash
# Check container status
docker ps | grep cynapse

# View container resource usage
docker stats node-app-container
```

## Candidate:

**Hiroshi Kaibara**

## Acknowledgments

This codebase was forked from [Heroku Node.js Sample](https://github.com/heroku/node-js-sample).  
The purpose of this project is solely to comply with the technical assessment; no other intentions are implied.

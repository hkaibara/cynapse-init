pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = "my-node-app"
        PREVIOUS_STABLE = ""
    }

    stages {
        stage('Initialization') {
            steps {
                script {
                    PREVIOUS_STABLE = sh(script: "docker inspect --format='{{.Config.Image}}' node-app-container || echo 'none'", returnStdout: true).trim()
                    echo "Current running image: ${PREVIOUS_STABLE}"
                }
            }
        }

        stage('Build Docker') {
            steps {
                script {
                    if (PREVIOUS_STABLE != "none") {
                        sh "docker tag ${DOCKER_IMAGE}:latest ${DOCKER_IMAGE}:backup"
                        echo "Previous latest tagged as backup"
                    }
                    sh "docker build --no-cache -t ${DOCKER_IMAGE}:latest ."
                    sh "docker image prune -f"
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    sh "docker stop node-app-container || true"
                    sh "docker rm node-app-container || true"
                    sh "docker run -d --name node-app-container -p 5000:5000 ${DOCKER_IMAGE}:latest"
                }
            }
        }
    }

    post {
        failure {
            script {
                if (PREVIOUS_STABLE != "none") {
                    echo "Build failed! Rolling back to previous image: ${DOCKER_IMAGE}:backup"
                    sh "docker stop node-app-container || true"
                    sh "docker rm node-app-container || true"
                    sh "docker run -d --name node-app-container -p 5000:5000 ${DOCKER_IMAGE}:backup"
                }
            }
        }
    }
}
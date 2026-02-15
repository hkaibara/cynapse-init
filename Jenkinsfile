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
                    sh "docker build --no-cache -t ${DOCKER_IMAGE}:latest ."
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
                if (PREVIOUS_IMAGE != "none" && PREVIOUS_IMAGE != "") {
                    echo "Build failed! Rolling back to previous image: ${PREVIOUS_IMAGE}"
                    sh "docker stop node-app-container || true"
                    sh "docker rm node-app-container || true"
                    sh "docker run -d --name node-app-container -p 5000:5000${PREVIOUS_IMAGE}"
                }
            }
        }
    }
}
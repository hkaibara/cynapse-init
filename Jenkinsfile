pipeline {
    agent any
    
    tools {
        nodejs "node18" 
    }

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

        stage('Unit Tests') {
            when { anyOf { branch 'feat/*'; changeRequest() } }
            steps {
                sh 'npm install && npm run test:unit'
            }
        }

        stage('Release & Tag') {
            when { branch 'main' }
            steps {
                nodejs('node20') {
                    sh 'git config user.email "hiroshi.kaibara.hk@gmail.com" && git config user.name "hkaibara"'
                    sh 'npx release-it --ci'
                }
            }
        }

        stage('Docker Build & Deploy') {
            when { buildingTag() }
            steps {
                script {
                    def version = sh(script: "git describe --tags --abbrev=0", returnStdout: true).trim()
                    sh "docker build -t ${DOCKER_IMAGE}:${version} -t ${DOCKER_IMAGE}:latest ."
                    
                    sh "docker stop node-app-container || true"
                    sh "docker rm node-app-container || true"
                    sh "docker run -d --name node-app-container -p 3000:3000 ${DOCKER_IMAGE}:${version}"
                }
            }
        }
    }

    post {
        failure {
            script {
                if (PREVIOUS_STABLE != "none" && PREVIOUS_STABLE != "") {
                    echo "Build failed! Rolling back to: ${PREVIOUS_STABLE}"
                    sh "docker stop node-app-container || true"
                    sh "docker rm node-app-container || true"
                    sh "docker run -d --name node-app-container -p 3000:3000 ${PREVIOUS_STABLE}"
                }
            }
        }
    }
}
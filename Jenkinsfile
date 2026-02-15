pipeline {
    agent any
    tools {
        nodejs "node18"
    }
    environment {
        DOCKER_IMAGE = "my-node-app"
        // Tracks the current active container for rollback
        PREVIOUS_STABLE = sh(script: "docker inspect --format='{{.Config.Image}}' node-app-container || echo 'none'", returnStdout: true).trim()
    }
    stages {
        stage('Unit Tests') {
            when { anyOf { branch 'feat/*'; changeRequest() } }
            steps {
                sh 'npm install && npm run test:unit'
            }
        }

        stage('Advanced Tests (PR only)') {
            when { changeRequest() }
            steps {
                sh 'npm run test:integration && npm run test:regression'
            }
        }

        stage('Release & Tag') {
            when { branch 'main' }
            steps {
                // Ensure git is configured for release-it
                sh 'git config user.email "hiroshi.kaibara.hk@gmail.com" && git config user.name "hkaibara"'
                sh 'npx release-it --ci'
            }
        }

        stage('Docker Build & Deploy') {
            when { buildingTag() }
            steps {
                script {
                    def version = sh(script: "git describe --tags --abbrev=0", returnStdout: true).trim()
                    sh "docker build -t ${DOCKER_IMAGE}:${version} -t ${DOCKER_IMAGE}:latest ."
                    
                    // Simple local deployment switch
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
                if (env.PREVIOUS_STABLE != "none" && env.TAG_NAME) {
                    echo "Build failed! Rolling back to: ${PREVIOUS_STABLE}"
                    sh "docker stop node-app-container || true"
                    sh "docker rm node-app-container || true"
                    sh "docker run -d --name node-app-container -p 3000:3000 ${PREVIOUS_STABLE}"
                }
            }
        }
    }
}
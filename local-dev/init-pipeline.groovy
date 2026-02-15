obs:
  - script: |
      pipelineJob('node-app-pipeline') {
          definition {
              cps {
                  script('''
                      pipeline {
                          agent any
                          environment {
                              // Using the variable from our .env / systemd override
                              APP_PORT = "${env.APP_PORT ?: '3000'}"
                              IMAGE_NAME = "node-js-app"
                              CONTAINER_NAME = "node-app-container"
                          }
                          stages {
                              stage('Clone Repository') {
                                  steps {
                                      git branch: 'main', url: 'https://github.com/heroku/node-js-sample.git'
                                  }
                              }
                              stage('Docker Build') {
                                  steps {
                                      sh "docker build -t ${IMAGE_NAME} ."
                                  }
                              }
                              stage('Cleanup Existing Container') {
                                  steps {
                                      // '|| true' ensures the pipeline doesn't fail if the container doesn't exist yet
                                      sh "docker stop ${CONTAINER_NAME} || true"
                                      sh "docker rm ${CONTAINER_NAME} || true"
                                  }
                              }
                              stage('Docker Deploy') {
                                  steps {
                                      // Bind only to localhost so Nginx is the only public entry point
                                      sh "docker run -d --name ${CONTAINER_NAME} -p 127.0.0.1:${APP_PORT}:3000 ${IMAGE_NAME}"
                                  }
                              }
                          }
                          post {
                              success {
                                  echo "Application deployed successfully at https://<VM-IP>"
                              }
                          }
                      }
                  '''.stripIndent())
                  sandbox()
              }
          }
      }
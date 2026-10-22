pipeline {
    agent any

    environment {
        IMAGE_NAME = 'devsecops-demo-app'
        CONTAINER_NAME = 'devsecops-demo-app'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                sh 'python3 -m venv venv'
                sh 'venv/bin/pip install -r requirements.txt'
            }
        }

        stage('Test Application') {
            steps {
                sh 'venv/bin/python -m unittest test_app.py'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    def scannerHome = tool 'SonarScanner'
                    withSonarQubeEnv('SonarQube') {
                        sh "${scannerHome}/bin/sonar-scanner"
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} .'
            }
        }

        stage('Deploy Container') {
            steps {
                sh 'docker rm -f ${CONTAINER_NAME} || true'
                sh 'docker run -d --name ${CONTAINER_NAME} -p 5000:5000 ${IMAGE_NAME}:${BUILD_NUMBER}'
            }
        }

        stage('Verify Deployment') {
            steps {
                sh 'sleep 5'
                sh 'curl -f http://localhost:5000/health'
            }
        }
    }
}

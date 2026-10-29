pipeline {
    agent any

    environment {
        IMAGE_NAME = 'kevinchris7/devsecops-demo-app'
        CONTAINER_NAME = 'devsecops-demo-app'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Gitleaks Secret Gate') {
            steps {
                sh 'gitleaks git -v --redact --exit-code 1 .'
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

        stage('SonarQube Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Snyk Dependency Gate') {
            steps {
                snykSecurity(
                    snykInstallation: 'Snyk',
                    snykTokenId: 'snyk-token',
                    targetFile: 'requirements.txt',
                    additionalArguments: '--command=venv/bin/python',
                    severity: 'high',
                    failOnIssues: true,
                    failOnError: true,
                    monitorProjectOnBuild: false
                )
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build --pull -t ${IMAGE_NAME}:${BUILD_NUMBER} .'
            }
        }

        stage('Verify Non-Root Container') {
            steps {
                sh 'docker run --rm ${IMAGE_NAME}:${BUILD_NUMBER} id -u | grep -vq "^0$"'
            }
        }

        stage('Trivy Image Gate') {
            steps {
                sh 'trivy image --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 ${IMAGE_NAME}:${BUILD_NUMBER}'
            }
        }

        stage('Push Image to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    sh 'echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USER" --password-stdin'
                    sh 'docker push ${IMAGE_NAME}:${BUILD_NUMBER}'
                    sh 'docker logout'
                }
            }
        }

        stage('Pull Published Image') {
            steps {
                sh 'docker image rm ${IMAGE_NAME}:${BUILD_NUMBER}'
                sh 'docker pull ${IMAGE_NAME}:${BUILD_NUMBER}'
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

    post {
        always {
            deleteDir()
        }
    }
}

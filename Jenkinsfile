pipeline {
    agent any

    environment {
        IMAGE_NAME = 'harshchauhan01/slug-api:latest'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                sh 'docker build -f docker/Dockerfile -t $IMAGE_NAME .'
            }
        }

        stage('Push Image') {
            steps {
                script {
                    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub-credentials') {
                        sh 'docker push $IMAGE_NAME'
                    }
                }
            }
        }
    }
}
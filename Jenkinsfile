pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        ansiColor('xterm')
    }

    environment {
        REGISTRY = 'docker.io'
        IMAGE_REPO = 'harshchauhan01/slug-api'
        KUBE_NAMESPACE = 'slugapi-ns'
        DOCKER_CREDENTIALS_ID = 'dockerhub-credentials'
        KUBECONFIG_CREDENTIALS_ID = 'kubeconfig-file'
        TERRAFORM_AUTO_APPLY = 'false'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_SHORT_SHA = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.IMAGE_TAG = "${env.GIT_SHORT_SHA}-${env.BUILD_NUMBER}"
                    env.IMAGE_URI = "${env.REGISTRY}/${env.IMAGE_REPO}:${env.IMAGE_TAG}"
                }
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    python -m pip install --upgrade pip
                    pip install -r requirements/dev.txt
                '''
            }
        }

        stage('Quality Gates') {
            parallel {
                stage('Lint + Static Analysis') {
                    steps {
                        sh '''
                            . .venv/bin/activate
                            flake8 .
                            bandit -q -r config slugs
                        '''
                    }
                }

                stage('Unit Tests') {
                    steps {
                        sh '''
                            . .venv/bin/activate
                            python manage.py test
                        '''
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -f docker/Dockerfile --target production -t ${IMAGE_URI} .'
            }
        }

        stage('Push Docker Image') {
            steps {
                script {
                    docker.withRegistry('https://index.docker.io/v1/', DOCKER_CREDENTIALS_ID) {
                        sh 'docker push ${IMAGE_URI}'
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir('terraform') {
                    sh '''
                        terraform init -input=false
                        terraform validate
                        terraform plan -input=false -out=tfplan
                    '''
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { return env.TERRAFORM_AUTO_APPLY == 'true' }
            }
            steps {
                dir('terraform') {
                    sh 'terraform apply -input=false -auto-approve tfplan'
                }
            }
        }

        stage('Deploy (kind)') {
            steps {
                sh '''
                    export TERRAFORM_AUTO_APPLY="${TERRAFORM_AUTO_APPLY}"
                    export IMAGE_URI="${IMAGE_URI}"
                    bash scripts/deploy.sh kind
                '''
            }
        }
    }

    post {
        success {
            echo "Pipeline succeeded. Deployed ${env.IMAGE_URI}"
        }
        failure {
            echo 'Pipeline failed. Review stage logs for root cause.'
        }
        always {
            cleanWs(deleteDirs: true)
        }
    }
}

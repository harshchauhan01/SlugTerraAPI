pipeline{
    agent any

    environment {
        REGISTRY = "harshchauhan01"
        IMAGE_NAME = "slug-api:latest"
        KUBE_NAMESPACE = "slugapi-ns"
    }
    stages{
        stage("Checkout"){
            steps{
                git branch: 'main', url: 'https://github.com/harshchauhan01/SlugTerraAPI.git'
            }
        }

        stage("Install Dependencies"){
            steps{
                sh '''
                python -m venv venv
                . venv/bin/activate
                pip install -r requirements.txt
                '''
            }
        }

        stages("Build Docker Image"){
            steps{
                script{
                    docker.build("${REGISTRY}/${IMAGE_NAME}")
                }
            }
        }

        stages("Push Docker Image"){
            steps{
                script{
                    docker.withRegistry('',DOCKER_CREDENTIALS_ID){
                        docker.image("${REGISTRY}/${IMAGE_NAME}").push()
                    }
                }
            }
        }

    }

    post{
        success{
            echo "Task Done"
        }
        failure{
            echo "Pipeline failed"
        }
    }
}
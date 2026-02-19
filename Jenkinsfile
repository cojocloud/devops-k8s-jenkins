pipeline {
    agent any

    environment {
        // Docker Hub credentials
        DOCKER_USERNAME = credentials('dockerhub-username')
        DOCKER_PASSWORD = credentials('dockerhub-password')

        // AWS credentials
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        AWS_DEFAULT_REGION    = 'us-west-2'   // change to your preferred region

        // Terraform variables (passed as environment variables)
        TF_VAR_dockerhub_username = "${DOCKER_USERNAME}"
        TF_VAR_region              = "${AWS_DEFAULT_REGION}"
        TF_VAR_cluster_name        = 'automated-demo-cluster'   // customize if needed
        TF_VAR_environment         = 'dev'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/Joebaho/K8S-TF-DOC-JEN.git'
            }
        }

        stage('Run Full Deployment') {
            steps {
                dir('scripts') {
                    sh '''
                        chmod +x deploy.sh
                        ./deploy.sh
                    '''
                }
            }
        }

        stage('Output Service URL') {
            steps {
                echo 'Deployment completed. Check the Jenkins console output for the LoadBalancer URL.'
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}
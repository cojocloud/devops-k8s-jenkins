pipeline {
    agent any

    stages {
        stage('Pull Code From GitHub') {
            steps {
                git "https://github.com/cojocloud/devops-k8s-jenkins.git"
            }
        }

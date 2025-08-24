pipeline {
    agent any

    environment {
        // Replace with your registry (DockerHub/GCR/ECR/etc.)
        clientRegistry = "docker.io/your-org/client"
        booksRegistry  = "docker.io/your-org/books"
        mainRegistry   = "docker.io/your-org/main"
        registryCredential = 'DockerHubLogin'   // Jenkins DockerHub creds
        gitCreds = 'git-credentials'            // Jenkins git creds
        repoUrl = 'https://github.com/your-org/kkart.git'
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    sh 'git pull'
                    env.GIT_COMMIT = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                }
            }
        }

        stage('Build & Push Angular Image') {
            when { changeset "client/*" }
            steps {
                script {
                    docker.withRegistry('', registryCredential) {
                        def img = docker.build("${clientRegistry}:${env.GIT_COMMIT}", "./client/")
                        img.push()
                        img.push('latest')
                    }
                }
            }
        }

        stage('Build & Push Books Image') {
            when { changeset "javaapi/*" }
            steps {
                script {
                    docker.withRegistry('', registryCredential) {
                        def img = docker.build("${booksRegistry}:${env.GIT_COMMIT}", "./javaapi/")
                        img.push()
                        img.push('latest')
                    }
                }
            }
        }

        stage('Build & Push Main Image') {
            when { changeset "nodeapi/*" }
            steps {
                script {
                    sh "sed -i 's/localhost/emongo/g' nodeapi/config/keys.js"
                    docker.withRegistry('', registryCredential) {
                        def img = docker.build("${mainRegistry}:${env.GIT_COMMIT}", "./nodeapi/")
                        img.push()
                        img.push('latest')
                    }
                }
            }
        }

        stage('Update Helm Values') {
            steps {
                script {
                    if (currentBuild.changeSets.any { it.affectedFiles.any { it.path.startsWith('client/') } }) {
                        sh "yq e -i '.image.tag = \"${env.GIT_COMMIT}\"' kkartchart/charts/frontend/values.yaml"
                    }
                    if (currentBuild.changeSets.any { it.affectedFiles.any { it.path.startsWith('javaapi/') } }) {
                        sh "yq e -i '.books.image.tag = \"${env.GIT_COMMIT}\"' kkartchart/charts/backend/values.yaml"
                    }
                    if (currentBuild.changeSets.any { it.affectedFiles.any { it.path.startsWith('nodeapi/') } }) {
                        sh "yq e -i '.main.image.tag = \"${env.GIT_COMMIT}\"' kkartchart/charts/backend/values.yaml"
                    }
                }
            }
        }

        stage('Commit & Push Changes') {
            steps {
                withCredentials([string(credentialsId: gitCreds, variable: 'GIT_TOKEN')]) {
                    sh '''
                        git config --global user.email "jenkins@example.com"
                        git config --global user.name "Jenkins"
                        git add kkartchart/charts/*/values.yaml
                        git commit -m "ci: update image tags to ${GIT_COMMIT}" || echo "No changes to commit"
                        git push ${repoUrl} HEAD:main
                    '''
                }
            }
        }
    }
}

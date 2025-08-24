pipeline {
    agent any
	
	environment {
        clientRegistry = "repository.k8sengineers.com/apexrepo/client"
        booksRegistry = "repository.k8sengineers.com/apexrepo/books"
        mainRegistry = "repository.k8sengineers.com/apexrepo/main"
        registryCredential = 'NexusRepoLogin'
        cartRegistry = "https://repository.k8sengineers.com"
    }
	
	stages {
	
	  stage('Build Angular Image') {
        when { changeset "client/*"}
	     steps {
		   
		     script {
                dockerImage = docker.build( clientRegistry + ":$BUILD_NUMBER", "./client/")
             }

		 }
	  
	  }
	  
	  stage('Deploy Angular Image') {
          when { changeset "client/*"}
          steps{
            script {
              docker.withRegistry( cartRegistry, registryCredential ) {
                dockerImage.push("$BUILD_NUMBER")
                dockerImage.push('latest')
              }
            }
          }
	   }

       stage('Kubernetes Deploy Angular') {
           when { changeset "client/*"}
            steps {
                  withCredentials([file(credentialsId: 'CartWheelKubeConfig1', variable: 'config')]){
                    sh """
                      export KUBECONFIG=\${config}
                      pwd
                      helm upgrade kubekart kkartchart --install --set "kkartcharts-frontend.image.client.tag=${BUILD_NUMBER}" --namespace kart
                      """
                  }
                 }  
        }

        stage('Build books Image') {
        when { changeset "javaapi/*"}
	     steps {
		   
		     script {
                dockerImage = docker.build( booksRegistry + ":$BUILD_NUMBER", "./javaapi/")
             }

		 }
	  
	  }
	  
	  stage('Deploy books Image') {
          when { changeset "javaapi/*"}
          steps{
            script {
              docker.withRegistry( cartRegistry, registryCredential ) {
                dockerImage.push("$BUILD_NUMBER")
                dockerImage.push('latest')
              }
            }
          }
	   }

       stage('Kubernetes books Deploy') {
           when { changeset "javaapi/*"}
            steps {
                  withCredentials([file(credentialsId: 'CartWheelKubeConfig1', variable: 'config')]){
                    sh """
                      export KUBECONFIG=\${config}
                      pwd
                      helm upgrade kubekart kkartchart --install --set "kkartcharts-backend.image.books.tag=${BUILD_NUMBER}" --namespace kart
                      """
                  }
                 }  
        }

        stage('Build Main Image') {
        when { changeset "nodeapi/*"}
	     steps {
		   
		     script {
                sh " sed -i 's/localhost/emongo/g' nodeapi/config/keys.js"
                dockerImage = docker.build( mainRegistry + ":$BUILD_NUMBER", "./nodeapi/")
             }

		 }
	  
	  }
	  
	  stage('Deploy Main Image') {
          when { changeset "nodeapi/*"}
          steps{
            script {
              docker.withRegistry( cartRegistry, registryCredential ) {
                dockerImage.push("$BUILD_NUMBER")
                dockerImage.push('latest')
              }
            }
          }
	   }

       stage('Kubernetes Main Deploy') {
           when { changeset "nodeapi/*"}
            steps {
                  withCredentials([file(credentialsId: 'CartWheelKubeConfig1', variable: 'config')]){
                    sh """
                      export KUBECONFIG=\${config}
                      pwd
                      pipeline {
    agent any

    environment {
        // PLEASE REPLACE with your docker registry
        clientRegistry = "your-docker-registry/client"
        booksRegistry = "your-docker-registry/books"
        mainRegistry = "your-docker-registry/main"
    }

    stages {
        stage('Prepare') {
            steps {
                script {
                    // Ensure we have the latest changes from the repository
                    sh 'git pull'
                    // Set the GIT_COMMIT environment variable
                    env.GIT_COMMIT = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                }
            }
        }

        stage('Build Angular Image') {
            when { changeset "client/*" }
            steps {
                script {
                    docker.build(clientRegistry + ":${env.GIT_COMMIT}", "./client/")
                }
            }
        }

        stage('Build books Image') {
            when { changeset "javaapi/*" }
            steps {
                script {
                    docker.build(booksRegistry + ":${env.GIT_COMMIT}", "./javaapi/")
                }
            }
        }

        stage('Build Main Image') {
            when { changeset "nodeapi/*" }
            steps {
                script {
                    sh "sed -i 's/localhost/emongo/g' nodeapi/config/keys.js"
                    docker.build(mainRegistry + ":${env.GIT_COMMIT}", "./nodeapi/")
                }
            }
        }

        stage('Update Frontend Image Tag') {
            when { changeset "client/*" }
            steps {
                sh "sed -i 's/^    tag: .*/    tag: ${env.GIT_COMMIT}/' kkartchart/charts/frontend/values.yaml"
            }
        }

        stage('Update Backend Image Tags') {
            when { anyOf { changeset "javaapi/*"; changeset "nodeapi/*" } }
            steps {
                script {
                    if (currentBuild.changeSets.any { it.affectedFiles.any { it.path.startsWith('javaapi/') } }) {
                        sh "sed -i '/repository: .*\/books/,/tag:/ s/tag: .*/tag: ${env.GIT_COMMIT}/' kkartchart/charts/backend/values.yaml"
                    }
                    if (currentBuild.changeSets.any { it.affectedFiles.any { it.path.startsWith('nodeapi/') } }) {
                        sh "sed -i '/repository: .*\/main/,/tag:/ s/tag: .*/tag: ${env.GIT_COMMIT}/' kkartchart/charts/backend/values.yaml"
                    }
                }
            }
        }

        stage('Commit and Push Changes') {
            when {
                expression { sh(script: "git status --porcelain | grep 'kkartchart/charts/frontend/values.yaml\|kkartchart/charts/backend/values.yaml'", returnStatus: true) == 0 }
            }
            steps {
                // PLEASE REPLACE with your git credentials and repo url
                withCredentials([string(credentialsId: 'git-credentials', variable: 'GIT_TOKEN')]) {
                    sh '''
                        git config --global user.email "jenkins@example.com"
                        git config --global user.name "Jenkins"
                        git add kkartchart/charts/frontend/values.yaml kkartchart/charts/backend/values.yaml
                        git commit -m "ci: update image tags to ${env.GIT_COMMIT}"
                        git push https://user:${GIT_TOKEN}@github.com/your-repo.git HEAD:main
                    '''
                }
            }
        }
    }
}

                      """
                  }
                 }  
        }
	}
}

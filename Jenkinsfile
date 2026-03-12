pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-northeast-2'
        ECR_REPO = 'demo-ecr'

        GITHUB_USER = 'cache-caching'
        GITHUB_ACCESS_TOKEN = credentials('github-access-token')
        GITHUB_MANIFEST_REPOSITORY_NAME = 'demo-manifest-repo'
        
        MANIFEST_FILE = 'deployment.yaml'
    }

    stages {
        stage('Checkout') {
            steps {
                echo "Git Checkout"
                checkout scm
            }
        }

        stage('Get AWS Account ID') {
            steps {
                script {
                    def accountId = sh(
                        script: "aws sts get-caller-identity --query Account --output text",
                        returnStatus: false,
                        returnStdout: true
                    ).trim()
                    
                    env.AWS_ACCOUNT_ID = accountId
                    env.ECR_REGISTRY = "${accountId}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                    echo "AWS Account ID: ${env.AWS_ACCOUNT_ID}"
                }
            }
        }

        stage('Determine Next Image Tag') {
            steps {
                script {
                    def stdout = sh(
                        script: "aws ecr list-images --region ${env.AWS_REGION} --repository-name ${env.ECR_REPO} --query 'imageIds[*].imageTag' --output text",
                        returnStdout: true
                    ).trim()

                    if (!stdout || stdout == 'None' || stdout == 'null' || stdout.isEmpty()) {
                        env.IMAGE_TAG = 'v1.0.0'
                    } else {
                        def existingTags = stdout.split(/\s+/)
                        def semverPattern = /^v\d+\.\d+\.\d+$/
                        def versions = existingTags.findAll { it =~ semverPattern }

                        if (versions) {
                            def latest = versions.sort { a, b ->
                                def aParts = a.replaceAll('v','').split('\\.').collect { it.toInteger() }
                                def bParts = b.replaceAll('v','').split('\\.').collect { it.toInteger() }
                                for (int i = 0; i < 3; i++) {
                                    if (aParts[i] != bParts[i]) return aParts[i] <=> bParts[i]
                                }
                                return 0
                            }.last()

                            def lastParts = latest.replaceAll('v','').split('\\.').collect { it.toInteger() }
                            lastParts[2] += 1
                            env.IMAGE_TAG = "v${lastParts.join('.')}"
                        } else {
                            env.IMAGE_TAG = 'v1.0.0'
                        }
                    }

                    env.DOCKER_IMAGE = "${env.ECR_REGISTRY}/${env.ECR_REPO}:${env.IMAGE_TAG}"
                    echo "Next Docker Image Tag: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Docker Build & Push') {
            steps {
                script {
                    echo "Building and Pushing Docker Image: ${env.DOCKER_IMAGE}"
                    sh """
                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    docker build -t ${DOCKER_IMAGE} .
                    docker push ${DOCKER_IMAGE}
                    """
                }
            }
        }

        stage('Update GitOps Manifest') {
            steps {
                withCredentials([string(credentialsId: "${GITHUB_ACCESS_TOKEN}", variable: 'GITHUB_TOKEN')]) {
                    sh """
                    rm -rf ${GITHUB_MANIFEST_REPOSITORY_NAME}
                    git clone https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_MANIFEST_REPOSITORY_NAME}.git
                    
                    sed -i "s|image: .*|image: ${DOCKER_IMAGE}|" ./${GITHUB_MANIFEST_REPOSITORY_NAME}/${MANIFEST_FILE}

                    git config user.email "skills@localhost"
                    git config user.name "skills"
                    
                    if git status | grep -q "${MANIFEST_FILE}"; then
                        git -C ./${GITHUB_MANIFEST_REPOSITORY_NAME} add ${MANIFEST_FILE}
                        git -C ./${GITHUB_MANIFEST_REPOSITORY_NAME} commit -m "Update image to ${IMAGE_TAG}"
                        git -C ./${GITHUB_MANIFEST_REPOSITORY_NAME} push origin main
                    else
                        echo "No changes to commit"
                    fi
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Build, Push, and Deploy completed: ${env.DOCKER_IMAGE}"
        }
        failure {
            echo "Pipeline failed! Check the logs above."
        }
        always {
            cleanWs()
        }
    }
}
pipeline {
    agent any

    triggers {
        githubPush()
    }

    environment {
        DOCKER_REGISTRY = 'docker.io'
        SONAR_HOST_URL = 'https://sonarcloud.io'
        DOCKER_REPO = 'kevinlagaza'
        IC_WEBAPP_IMAGE = "${DOCKER_REPO}/ic-webapp"
        DOCKER_CREDENTIALS_ID = 'dockerhub-credentials'
        // Sonarqube
        SONAR_PROJECT_KEY = credentials('sonar-project-key')
        SONAR_ORGANIZATION = credentials('sonar-organization')
        SSH_CREDENTIALS_ID = 'prod-server-ssh' 
        PROD_SERVER_IP = credentials('prod-server-ip')
        ANSIBLE_HOST_KEY_CHECKING = 'False'
        TRIVY_SEVERITY = 'CRITICAL,HIGH'

    }

    stages {

        stage('Checkout and Extract Version') {
            steps {
                checkout scm
                script {
                    env.VERSION = sh(
                        script: "awk -F': ' '/^version:/ {print \$2}' releases.txt",
                        returnStdout: true
                    ).trim()
                    env.BRANCH_NAME = env.GIT_BRANCH?.replaceAll('origin/', '') ?: 'unknown'

                    echo "Version: ${env.VERSION}"
                    echo "Branch: ${env.BRANCH_NAME}"
                }
            }
        }

        stage('Security Scan - Code') {
            parallel {
                stage('SonarQube Analysis') {
                    steps {
                        echo '========== SONARQUBE ANALYSIS =========='
                        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                            sh """
                            docker run --rm \
                                    -v \$(pwd):/usr/src \
                                    sonarsource/sonar-scanner-cli \
                                    -Dsonar.host.url=${SONAR_HOST_URL} \
                                    -Dsonar.token=\${SONAR_TOKEN} \
                                    -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                    -Dsonar.organization=${SONAR_ORGANIZATION} \
                                    -Dsonar.projectVersion=${VERSION} \
                                    -Dsonar.sources=. \
                                    -Dsonar.python.version=3.11 \
                                    -Dsonar.exclusions=**/*.html,**/*.css,**/*.js
                            """
                        }
                        echo '========== FINISHED SONARQUBE ANALYSIS =========='
                    }
                }

                stage('SAST - Bandit') {
                    steps {
                        sh """
                            docker run --rm -v \$(pwd):/code python:3.11-slim \
                                /bin/bash -c "pip install -q bandit && bandit -r /code -ll -f json -o /code/bandit-report.json || true"
                        """
                    }
                }

                stage('Secrets - Gitleaks') {
                    steps {
                        sh """
                            docker run --rm -v \$(pwd):/path zricethezav/gitleaks:latest \
                                detect --source=/path --report-path=/path/gitleaks-report.json || true
                        """
                    }
                }
            }
        }

        stage('Build') {
            steps {
                sh """
                    # Delete the orphaned images
                    docker image prune -f || true
                    # Delete the specific image to ensure a clean build
                    docker rmi ${IC_WEBAPP_IMAGE}:${VERSION} 2>/dev/null || true
                    # Build the image without cache to ensure all layers are fresh
                    docker build --no-cache -t ${IC_WEBAPP_IMAGE}:${VERSION} .
                """
            }
        }

        stage('Security Scan - Images') {
            steps {
                sh """
                    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                        aquasec/trivy:latest image \
                        --severity ${TRIVY_SEVERITY} \
                        --exit-code 1 \
                        --ignore-unfixed \
                        ${IC_WEBAPP_IMAGE}:${VERSION}
                """
            }
        }

        stage('Test') {
            when { anyOf { branch 'develop'; branch 'feature/*' } }
            steps {
                sh """
                    docker network create test-net-${BUILD_NUMBER} || true
                    
                    docker run -d --name ic-test-${BUILD_NUMBER} \
                        --network test-net-${BUILD_NUMBER} \
                        -p 8081:8080 \
                        ${IC_WEBAPP_IMAGE}:${VERSION}
                    
                    sleep 10
                    
                    docker ps
                    # Retrieve the IP of the container
                    CONTAINER_IP=\$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ic-test-${BUILD_NUMBER})
            
                    # Test the application
                    docker exec ic-test-${BUILD_NUMBER} curl -sf http://\${CONTAINER_IP}:8080 || exit 1

                    # Verify the environment variables are set correctly
                    docker exec ic-test-${BUILD_NUMBER} cat /opt/env.sh | grep -q ODOO_URL || exit 1
                    docker exec ic-test-${BUILD_NUMBER} cat /opt/env.sh | grep -q PGADMIN_URL || exit 1
                    
                    echo "Tests passed"
                """
            }
            post {
                always {
                    sh """
                        docker stop ic-test-${BUILD_NUMBER} || true
                        docker rm ic-test-${BUILD_NUMBER} || true
                        docker network rm test-net-${BUILD_NUMBER} || true
                    """
                }
            }
        }

        stage('Push') {
            when { anyOf { branch 'develop'; branch 'main' } }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: "${DOCKER_CREDENTIALS_ID}",
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh """
                        echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin
                        docker push ${IC_WEBAPP_IMAGE}:${VERSION}
                        docker logout
                    """
                }
            }
        }

        stage('Deploy with Ansible') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: "${SSH_CREDENTIALS_ID}",
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    sh """
                        # Create dynamic inventory
                        cat > inventory.yml << EOF
all:
  hosts:
    prod:
      ansible_host: ${PROD_SERVER_IP}
      ansible_user: ubuntu
      ansible_ssh_private_key_file: ${SSH_KEY}
EOF

                        # Create playbook
                        cat > deploy.yml << EOF
---
- name: Deploy IC-Webapp Stack
  hosts: prod
  become: true

  vars:
    ic_webapp_image: "${IC_WEBAPP_IMAGE}"
    ic_webapp_version: "${VERSION}"
    odoo_port: 8069
    pgadmin_port: 5050
    ic_webapp_port: 8080

  roles:
    - role: odoo_role
    - role: pgadmin_role
    - role: ic_webapp_role
      vars:
        container_name: "ic-webapp"
        app_image: "{{ ic_webapp_image }}:{{ ic_webapp_version }}"
        app_port: "{{ ic_webapp_port }}"
EOF

                        # Run Ansible
                        ansible-playbook -i inventory.yml deploy.yml
                    """
                }
            }
        }

        stage('Verify Deployment') {
            when {
                branch 'main'
            }
            steps {
                sh """
                    sleep 30
                    
                    echo "=== Health Checks ==="
                    curl -sf http://${PROD_SERVER_IP}:8080 && echo "IC-Webapp: OK" || echo "IC-Webapp: FAILED"
                    curl -sf http://${PROD_SERVER_IP}:8069 && echo "Odoo: OK" || echo "Odoo: FAILED"
                    curl -sf http://${PROD_SERVER_IP}:5050 && echo "PgAdmin: OK" || echo "PgAdmin: FAILED"
                """
            }
        }
    }

    post {
        always {
            sh "docker system prune -f || true"
            cleanWs()
        }
        success {
            echo "✅ Pipeline execution successful for branch ${env.GIT_BRANCH}!"
            echo """
            ==========================================
            Deployment Successful - Version ${VERSION}
            ==========================================
            """
        }
        failure {
            echo "❌ Pipeline execution failed!"
        }
    }
}
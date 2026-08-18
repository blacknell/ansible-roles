pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Validate Ansible') {
            steps {
                sh 'ansible --version'
            }
        }

        stage('Syntax check roles') {
            environment {
                // ansible-playbook resolves "roles:" relative to the playbook's
                // own directory (roles/<name>/tests/), not the repo root - point
                // it at the real roles/ dir so each role actually resolves.
                ANSIBLE_ROLES_PATH = "${WORKSPACE}/roles"
            }
            steps {
                sh '''
                    set -e
                    for test_playbook in roles/*/tests/test.yml; do
                        role_dir=$(dirname "$(dirname "$test_playbook")")
                        role_name=$(basename "$role_dir")
                        echo "== Syntax checking $role_name =="
                        ansible-playbook "$test_playbook" -i "$role_dir/tests/inventory" --syntax-check
                    done
                '''
            }
        }
    }

    post {
        failure {
            echo "Syntax check failed - see the console output above for which role and file."
        }
    }
}

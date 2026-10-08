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

        stage('Lint roles') {
            environment {
                ANSIBLE_ROLES_PATH = "${WORKSPACE}/roles"
            }
            steps {
                sh '''
                    ansible-lint --version
                    ansible-galaxy collection install -r requirements.yml
                    # No --strict: warn_list rules are reported but don't fail
                    # the build; real violations exit non-zero and do.
                    # --sarif-file also writes machine-readable results for
                    # Warnings NG, alongside the normal console output.
                    ansible-lint --sarif-file ansible-lint.sarif roles/
                '''
            }
            post {
                always {
                    // Publishes an "Ansible Lint" GitHub check with warning/error
                    // counts and per-line annotations. Runs even if lint failed.
                    recordIssues(
                        enabledForFailure: true,
                        tools: [sarif(pattern: 'ansible-lint.sarif',
                                      id: 'ansible-lint',
                                      name: 'Ansible Lint')]
                    )
                }
            }
        }
    }

    post {
        failure {
            echo "Syntax check failed - see the console output above for which role and file."
        }
    }
}

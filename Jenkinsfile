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
                    // Sets the "lint issues" README badge: total errors+warnings,
                    // green for 0, yellow for warnings only, red for any errors.
                    script {
                        def counts = sh(returnStdout: true, script: """
                            python3 - 'ansible-lint.sarif' <<'EOF'
import json, os, sys
path = sys.argv[1]
if not os.path.exists(path):
    print("-1 -1"); sys.exit(0)
# ansible-lint can report the same violation twice; count each unique
# file/line/rule/message once, matching Warnings NG's de-duplication.
seen = {}
for run in json.load(open(path)).get("runs", []):
    for result in run.get("results", []):
        loc = (result.get("locations") or [{}])[0].get("physicalLocation", {})
        key = (loc.get("artifactLocation", {}).get("uri"),
               loc.get("region", {}).get("startLine"),
               result.get("ruleId"),
               result.get("message", {}).get("text"))
        seen[key] = result.get("level", "warning")
errors = sum(1 for level in seen.values() if level == "error")
warnings = len(seen) - errors
print(errors, warnings)
EOF
                        """).trim().split()
                        def errors = counts[0] as int
                        def warnings = counts[1] as int
                        def badge = addEmbeddableBadgeConfiguration(id: 'lint', subject: 'lint issues')
                        if (errors < 0) {
                            badge.setStatus('unknown')
                            badge.setColor('lightgrey')
                        } else {
                            badge.setStatus("${errors + warnings}")
                            badge.setColor(errors > 0 ? 'red' : (warnings > 0 ? 'yellow' : 'brightgreen'))
                        }
                    }
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

pipeline {
    agent any

    environment {
        // Tools installed by 'Install tooling' come first on PATH.
        PATH = "${WORKSPACE}/.ci-venv/bin:${env.PATH}"
        // Collections go in this job's own workspace, not the shared
        // /root/.ansible/collections. Every build on the built-in node shares
        // HOME=/root, so two builds running 'install --force' at once (e.g. the
        // PR build and the branch build triggered by the same push) would
        // delete/rewrite each other's collection dirs mid-install, and a
        // half-deleted collection there shadows the copy bundled with ansible.
        ANSIBLE_COLLECTIONS_PATH = "${WORKSPACE}/.ci-collections"
    }

    stages {

        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Install tooling') {
            steps {
                // Latest ansible (full package, incl. community collections, as the
                // old apt package had) and ansible-lint from pip, rather than the
                // agent's apt packages, so CI tracks current releases. Reused across builds,
                // upgraded each run. PATH above puts it ahead of system ansible.
                sh '''
                    python3 -m venv .ci-venv
                    .ci-venv/bin/pip install --quiet --upgrade pip ansible ansible-lint
                    ansible --version
                    ansible-lint --version
                '''
            }
        }

        stage('Validate Ansible') {
            steps {
                sh 'ansible --version'
            }
        }

        stage('Install collections') {
            steps {
                sh 'ansible-galaxy collection install -r requirements.yml --force -p "${ANSIBLE_COLLECTIONS_PATH}"'
            }
        }

        // The version in galaxy.yml is the release number; its notes come from
        // the matching "## <version>" section of CHANGELOG.md, so make sure it's there.
        stage('Check changelog') {
            steps {
                sh """
                    v=\$(python3 -c "import yaml; print(yaml.safe_load(open('galaxy.yml'))['version'])")
                    grep -qx "## \$v" CHANGELOG.md || { echo "CHANGELOG.md has no '## \$v' section"; exit 1; }
                """
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
                // ansible-lint also searches ~/.ansible/collections, even with
                // ANSIBLE_COLLECTIONS_PATH set. On the built-in node that's the
                // shared /root/.ansible/collections, where a half-deleted
                // community.general from another job's 'install --force' shadows
                // the good copy ("couldn't resolve module/action
                // 'community.general.homebrew'"). A per-job HOME keeps it out.
                HOME = "${WORKSPACE}/.ci-home"
            }
            steps {
                sh '''
                    ansible-lint --version
                    # No --strict: warn_list rules are reported but don't fail
                    # the build; real violations exit non-zero and do.
                    # --sarif-file also writes machine-readable results for
                    # Warnings NG, alongside the normal console output.
                    # --offline stops ansible-lint running its own
                    # "ansible-galaxy collection install" into the shared
                    # /root/.ansible/collections; the collections it needs are
                    # already in this workspace from 'Install collections'.
                    ansible-lint --offline --sarif-file ansible-lint.sarif roles/
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

        // On main only: if galaxy.yml's version has no tag yet, create the GitHub
        // release (which also creates the tag) with that version's CHANGELOG.md
        // section as its notes, then tell Slack. Merges that don't bump the
        // version do nothing.
        stage('Release') {
            when { allOf { branch 'main'; not { changeRequest() } } }
            steps {
                withCredentials([usernamePassword(credentialsId: 'jenkins-pat-key',
                                                  usernameVariable: 'GH_USER', passwordVariable: 'GH_TOKEN')]) {
                    sh '''
                        set -eu
                        rm -f release.version release-notes.md release.json
                        v=$(python3 -c "import yaml; print(yaml.safe_load(open('galaxy.yml'))['version'])")
                        if git ls-remote --exit-code --tags https://github.com/blacknell/ansible-roles.git "refs/tags/$v" >/dev/null; then
                            echo "$v is already released"
                            exit 0
                        fi
                        awk -v h="## $v" '$0 == h { f = 1; next } /^## / { f = 0 } f' CHANGELOG.md > release-notes.md
                        python3 - "$v" "$GIT_COMMIT" > release.json <<'EOF'
import json, sys
v, sha = sys.argv[1:3]
print(json.dumps({"tag_name": v, "target_commitish": sha, "name": v,
                  "body": open("release-notes.md").read().strip()}))
EOF
                        curl -fsS -X POST -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" https://api.github.com/repos/blacknell/ansible-roles/releases --data @release.json > /dev/null
                        echo "$v" > release.version
                    '''
                }
                script {
                    if (fileExists('release.version')) {
                        def v = readFile('release.version').trim()
                        def notes = readFile('release-notes.md').trim()
                        slackSend color: 'good',
                                  channel: '#nomad-website',
                                  message: "blacknell.ansible_roles *${v}* released: https://github.com/blacknell/ansible-roles/releases/tag/${v}\n${notes}"
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

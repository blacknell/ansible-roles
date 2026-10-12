# ansible-role-jenkins_docker

Installs and backs up a [Jenkins](https://www.jenkins.io/) controller running under
Docker Compose, with `JENKINS_HOME` on a named Docker volume.

**Install** writes a compose project to `jenkins_docker_compose_dir` – `docker-compose.yml`,
a `Dockerfile` built on the Jenkins image, `plugins.txt` and an optional `casc/` folder for
Configuration as Code – then builds the image and starts the container. The image is
rebuilt only when one of those files changes, and compose recreates the container when
the image or its settings change. Plugins already installed in `JENKINS_HOME` are left
alone: removing a plugin from the list stops it being baked into the image, but you
still uninstall it in Jenkins.

**Backups** write two tarballs to `jenkins_docker_backup_dir`, nightly from cron or on
demand:

- `jenkins-home-<stamp>.tar.gz` – the `JENKINS_HOME` volume, minus rebuildable folders
  (`workspace`, `caches`, `war`, `updates`). It's made in a throwaway container, so the
  host user needs no access to the volume.
- `jenkins-config-<stamp>.tar.gz` – the compose folder (compose file, Dockerfile, casc, ...).
  Optional.

`<stamp>` comes from `jenkins_docker_backup_stamp_format`, e.g. `20261021-162836`.
Both files are mode `0600` and owned by `jenkins_docker_user`, because they contain
credentials. A backup fails, and nothing is reported as OK, if the volume doesn't exist or
the home tarball is smaller than `jenkins_docker_backup_min_home_bytes`.

## Requirements

- Linux host with Docker and the Compose plugin (`docker compose`), `flock` (util-linux)
  and GNU coreutils
- `jenkins_docker_user` can run `docker` (usually: is in the `docker` group)
- sudo for `install` and `backup_install`. The play doesn't need `become: true`; the
  tasks escalate as needed
- Ansible core >= 2.15 and the `community.docker` collection
- One Jenkins instance per host (the script path and cron entry name are single values)

## Role Variables

### Required

| Variable | Description |
|---|---|
| `jenkins_docker_user` | User that owns the compose project and runs backups |
| `jenkins_docker_compose_dir` | Folder the compose project is written to |
| `jenkins_docker_volume` | Docker volume mounted as `JENKINS_HOME` – exact name, created if missing |

These have no defaults; `meta/argument_specs.yml` makes the role stop with a clear error
if any is missing. Taking over an existing install? Set `jenkins_docker_volume` to the
volume's current name (`docker volume ls`), or Jenkins starts with an empty home.

### Install

| Variable | Default | Description |
|---|---|---|
| `jenkins_docker_compose_project` | basename of `jenkins_docker_compose_dir` | Compose project name |
| `jenkins_docker_image` | `jenkins/jenkins:lts-jdk21` | Base image the controller is built from |
| `jenkins_docker_plugins` | `[]` | Plugins baked into the image, as `id` or `id:version` |
| `jenkins_docker_apt_packages` | `[]` | Extra Debian packages installed into the image |
| `jenkins_docker_container_name` | `jenkins` | Container name |
| `jenkins_docker_container_user` | `""` | User the container runs as (`""` = the image's `jenkins` user) |
| `jenkins_docker_ports` | `["8080:8080", "50000:50000"]` | Published ports |
| `jenkins_docker_environment` | `{}` | Extra environment variables |
| `jenkins_docker_restart_policy` | `unless-stopped` | Compose restart policy |
| `jenkins_docker_docker_socket` | `false` | Mount `/var/run/docker.sock` so builds can run `docker` |
| `jenkins_docker_casc` | `false` | Mount `<compose_dir>/casc` and set `CASC_JENKINS_CONFIG` to it |
| `jenkins_docker_casc_src` | `""` | Folder on the Ansible controller whose files are copied into `casc/` (Jenkins is restarted when they change) |

### Backups

| Variable | Default | Description |
|---|---|---|
| `jenkins_docker_backup_dir` | `<compose_dir>/backups` | Where the tarballs are written |
| `jenkins_docker_backup_script` | `/usr/local/bin/jenkins-docker-backup` | Where the backup script is installed |
| `jenkins_docker_backup_log` | `/var/log/jenkins-docker-backup.log` | Log appended to by scheduled and manual runs |
| `jenkins_docker_backup_image` | `debian:trixie-slim` | Image used to tar the volume (needs GNU tar) |
| `jenkins_docker_backup_stamp_format` | `%Y%m%d-%H%M%S` | `date` format for the filename stamp (no spaces or slashes) |
| `jenkins_docker_backup_keep_days` | `7` | Local tarballs older than this are deleted |
| `jenkins_docker_backup_min_home_bytes` | `1048576` | A home tarball smaller than this fails the backup |
| `jenkins_docker_backup_cron` | `true` | Schedule the nightly backup |
| `jenkins_docker_backup_cron_name` | `jenkins backup` | Name of the cron entry |
| `jenkins_docker_backup_cron_hour` / `_minute` | `"3"` / `"15"` | Cron schedule |
| `jenkins_docker_backup_excludes` | `[workspace, caches, war, updates]` | Paths relative to `JENKINS_HOME` left out of the backup |
| `jenkins_docker_backup_extra_excludes` | `[]` | Extra excludes added to the list above |
| `jenkins_docker_backup_config` | `true` | Also tar the compose folder |
| `jenkins_docker_backup_config_excludes` | `[.git]` | Paths relative to the compose folder left out of the config tarball |

If the backup folder is inside the compose folder, it's left out of the config tarball and
the image build context automatically.

Backup settings are written into the backup script at install time. After changing any of
them, run `backup_install` again; `backup_now` uses the installed script as it is.

## Entry Points

| Entry point | Tag (via `main`) | What it does |
|---|---|---|
| `install` | `install` | Compose folder, `docker-compose.yml`, `Dockerfile`, `plugins.txt`, `casc/`; builds the image when they change and starts Jenkins |
| `backup_install` | `backup_install` | Backup folder, log file, script and cron entry |
| `backup_now` | `backup_now` | Checks the backup install, runs a backup as `jenkins_docker_user` and verifies the tarballs. Installs nothing. |

`main` runs `install` then `backup_install`. `backup_now` only runs when asked for
(`--tags backup_now` or `tasks_from: backup_now`).

Tasks that act as `jenkins_docker_user` only use `become` when the play isn't already
connected as that user, so `backup_now` needs no sudo when you connect as that user.

## Dependencies

None (the `community.docker` collection must be installed).

## Example Playbook

This role is distributed as part of the `blacknell.ansible_roles` collection. Add it to
your `requirements.yml`:

```yaml
collections:
  - name: https://github.com/blacknell/ansible-roles.git
    type: git
    version: main
  - name: community.docker
```

Then reference it by its fully-qualified name:

```yaml
- hosts: jenkins_hosts
  vars:
    jenkins_docker_user: jenkins
    jenkins_docker_compose_dir: /srv/jenkins
    jenkins_docker_volume: jenkins_jenkins-data
    jenkins_docker_image: jenkins/jenkins:lts-jdk21
    jenkins_docker_plugins:
      - configuration-as-code
      - workflow-aggregator
    jenkins_docker_casc: true
    jenkins_docker_casc_src: files/jenkins/casc
  roles:
    - blacknell.ansible_roles.jenkins_docker
```

```bash
ansible-playbook -i inventory jenkins.yml                         # install + backups
ansible-playbook -i inventory jenkins.yml --tags install          # Jenkins only
ansible-playbook -i inventory jenkins.yml --tags backup_now       # back up now
```

Add `-K` if sudo on the host asks for a password.

Or call an entry point directly, e.g. to take a backup before an upgrade:

```yaml
- ansible.builtin.include_role:
    name: blacknell.ansible_roles.jenkins_docker
    tasks_from: backup_now
```

## Testing

A minimal local test playbook is provided under `tests/`:

```bash
ansible-playbook -i tests/inventory tests/test.yml --syntax-check
```

## License

MIT

## Author Information

Paul Blacknell

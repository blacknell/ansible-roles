# ansible-role-jenkins_docker

Scheduled and on-demand backups for a [Jenkins](https://www.jenkins.io/) controller running
under Docker (typically Docker Compose), with `JENKINS_HOME` on a named Docker volume.

Each backup writes two tarballs to `jenkins_docker_backup_dir`:

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

- Linux host with Docker, `flock` (util-linux) and GNU coreutils
- `jenkins_docker_user` can run `docker` (usually: is in the `docker` group)
- sudo for `backup_install` – it writes the script, log file and backup folder. The play
  doesn't need `become: true`; the tasks escalate as needed
- Ansible core >= 2.15
- One Jenkins instance per host (the script path and cron entry name are single values)

## Role Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `jenkins_docker_user` | Yes | none | User that owns the compose project and runs backups |
| `jenkins_docker_compose_dir` | Yes | none | Folder holding `docker-compose.yml`, Dockerfile, etc. |
| `jenkins_docker_volume` | Yes | none | Docker volume mounted as `JENKINS_HOME` |
| `jenkins_docker_backup_dir` | Yes | none | Where the tarballs are written |
| `jenkins_docker_backup_script` | No | `/usr/local/bin/jenkins-docker-backup` | Where the backup script is installed |
| `jenkins_docker_backup_log` | No | `/var/log/jenkins-docker-backup.log` | Log appended to by scheduled and manual runs |
| `jenkins_docker_backup_image` | No | `debian:trixie-slim` | Image used to tar the volume (needs GNU tar) |
| `jenkins_docker_backup_stamp_format` | No | `%Y%m%d-%H%M%S` | `date` format for the filename stamp (no spaces or slashes) |
| `jenkins_docker_backup_keep_days` | No | `7` | Local tarballs older than this are deleted |
| `jenkins_docker_backup_min_home_bytes` | No | `1048576` | A home tarball smaller than this fails the backup |
| `jenkins_docker_backup_cron` | No | `true` | Schedule the nightly backup |
| `jenkins_docker_backup_cron_name` | No | `jenkins backup` | Name of the cron entry |
| `jenkins_docker_backup_cron_hour` / `_minute` | No | `"3"` / `"15"` | Cron schedule |
| `jenkins_docker_backup_excludes` | No | `[workspace, caches, war, updates]` | Paths relative to `JENKINS_HOME` left out of the backup |
| `jenkins_docker_backup_extra_excludes` | No | `[]` | Extra excludes added to the list above |
| `jenkins_docker_backup_config` | No | `true` | Also tar the compose folder |
| `jenkins_docker_backup_config_excludes` | No | `[.git]` | Paths relative to the compose folder left out of the config tarball |

The four required variables have no defaults; `meta/argument_specs.yml` makes the role
stop with a clear error if any is missing. If the backup folder is inside the compose folder,
it's left out of the config tarball automatically.

Settings are written into the backup script at install time. After changing any of them,
run `backup_install` again; `backup_now` uses the installed script as it is.

## Entry Points

| Entry point | Tag (via `main`) | What it does |
|---|---|---|
| `backup_install` | `backup_install` | Backup folder, log file, script and cron entry |
| `backup_now` | `backup_now` | Checks the install, runs a backup as `jenkins_docker_user` and verifies the tarballs. Installs nothing. |

`main` runs `backup_install`. `backup_now` only runs when asked for (`--tags backup_now`
or `tasks_from: backup_now`).

Tasks that act as `jenkins_docker_user` only use `become` when the play isn't already
connected as that user, so `backup_now` needs no sudo when you connect as the Jenkins user.

## Dependencies

None.

## Example Playbook

This role is distributed as part of the `blacknell.ansible_roles` collection. Add it to
your `requirements.yml`:

```yaml
collections:
  - name: https://github.com/blacknell/ansible-roles.git
    type: git
    version: main
```

Then reference it by its fully-qualified name:

```yaml
- hosts: jenkins_hosts
  vars:
    jenkins_docker_user: jenkins
    jenkins_docker_compose_dir: /srv/jenkins
    jenkins_docker_volume: jenkins_jenkins-data
    jenkins_docker_backup_dir: /srv/jenkins-backups
  roles:
    - blacknell.ansible_roles.jenkins_docker
```

```bash
ansible-playbook -i inventory jenkins.yml -K                    # install / refresh
ansible-playbook -i inventory jenkins.yml --tags backup_now     # back up now
```

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

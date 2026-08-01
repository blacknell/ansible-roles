# ansible-role-logrotate

Installs `logrotate` and deploys `/etc/logrotate.d/` configs for a fixed list of
services. Each config is rendered from a template — the log path(s) it rotates come
from a per-service variable (defaulted to what this role has always rotated), so a
consuming playbook can point a service at different paths, or drop a service
entirely, without forking the role.

## Requirements

- Debian (or a Debian-based distribution)
- The play must run with `become: true`, since the role installs a package and
  writes to `/etc/logrotate.d`

## Role Variables

`logrotate_services` is a dict of service name → `true`/`false`, controlling which
configs get deployed. Setting a service to `false` also removes its config file from
`/etc/logrotate.d/` if one is already present (e.g. left over from when it was
previously `true`) — it's not just skipped, it's actively cleaned up. Defaults to all
of them enabled:

```yaml
logrotate_services:
  apache2: true
  apt: true
  cron: true
  fail2ban: true
  heating: true
  homeauto: true
  homeautogit: true
  jenkins: true
  mongo: true
  monitor: true
  mqttlogger: true
  mysql-server: true
  nodered: true
  nomad: true
  rsyslog: true
  sleepylizard: true
  supervisord: true
```

To disable a service this host doesn't run, override it with `combine()` so you only
touch the service(s) you care about:

```yaml
# host_vars/myhost.yml
logrotate_services: "{{ logrotate_services | combine({'jenkins': false}) }}"
```

**Don't** override with a plain dict literal (`logrotate_services: {jenkins: false}`)
— Ansible replaces the whole variable rather than merging dicts, so every other
service would silently end up undefined and get skipped too. Always go through
`combine()` against the existing `logrotate_services`.

Each service also has its own `logrotate_<service>_paths` list (underscores, even
for `mysql-server` → `logrotate_mysql_server_paths`), overridable independently of
the others:

| Variable                        | Default                                                                 |
|-----------------------------------|--------------------------------------------------------------------------|
| `logrotate_apache2_paths`         | `/var/log/apache2/*.log`                                                  |
| `logrotate_apt_paths`             | `/var/log/apt/term.log`, `/var/log/apt/history.log`                       |
| `logrotate_cron_paths`            | `/var/log/cron.log`                                                       |
| `logrotate_fail2ban_paths`        | `/var/log/fail2ban.log`                                                   |
| `logrotate_heating_paths`         | `/var/log/heating.log`                                                    |
| `logrotate_homeauto_paths`        | `/var/log/homeauto.log`                                                   |
| `logrotate_homeautogit_paths`     | `/var/tmp/*-git.log`                                                      |
| `logrotate_jenkins_paths`         | `/var/log/jenkins/jenkins.log`, `/var/log/jenkins/access_log`             |
| `logrotate_mongo_paths`           | `/var/log/mongodb/*.log`                                                  |
| `logrotate_monitor_paths`         | `/var/log/monitor.readings.log`, `/var/log/monitor.log`, `/var/log/workshop.log` |
| `logrotate_mqttlogger_paths`      | `/var/log/mqtt*.log`                                                      |
| `logrotate_mysql_server_paths`    | `/var/log/mysql/mysql.log`, `/var/log/mysql/mysql-slow.log`, `/var/log/mysql/mariadb-slow.log`, `/var/log/mysql/error.log` |
| `logrotate_nodered_paths`         | `/var/log/nodered-install.log`                                            |
| `logrotate_nomad_paths`           | `/var/log/nomad.log`                                                      |
| `logrotate_rsyslog_paths`         | `/var/log/syslog` + 11 other standard syslog destinations                 |
| `logrotate_sleepylizard_paths`    | `/var/log/sleepylizard.log`                                               |
| `logrotate_supervisord_paths`     | `/var/log/supervisor/supervisord.log`                                     |

The rotation options (frequency, retention, `create` owner/group, pre/postrotate
scripts) are not parameterised — only the log path(s) each config targets. If you
need different options too, fork the relevant `templates/<service>.j2`.

Note: `apt` rotates `term.log` and `history.log` as a single combined stanza (both
paths share the same options) rather than as Debian's default two separate stanzas —
functionally identical, just one block instead of two.

Each rendered config is checked with `logrotate -d` (dry-run/debug mode) before being
installed — if a template renders invalid logrotate syntax, the task fails rather than
deploying a broken config.

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

Then reference it by its fully-qualified name. To disable a service you don't run and
override another service's paths:

```yaml
- hosts: debian_hosts
  become: true
  vars:
    logrotate_services: "{{ logrotate_services | combine({'jenkins': false}) }}"
    logrotate_apache2_paths:
      - /var/log/apache2/*.log
      - /var/log/apache2-vhosts/*.log
  roles:
    - blacknell.ansible_roles.logrotate
```

Or set these per-host in `host_vars`/`group_vars` instead of inline in the play.

## Testing

A minimal local test playbook is provided under `tests/`:

```bash
ansible-playbook -i tests/inventory tests/test.yml
```

## License

MIT

## Author Information

Paul Blacknell

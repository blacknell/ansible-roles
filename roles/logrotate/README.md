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

`logrotate_services` controls which configs get deployed. Defaults to all of the
following; override it (e.g. in `host_vars`) to drop entries for services this host
doesn't run:

```yaml
logrotate_services:
  - apache2
  - apt
  - cron
  - fail2ban
  - heating
  - homeauto
  - homeautogit
  - jenkins
  - mongo
  - monitor
  - mqttlogger
  - mysql-server
  - nodered
  - nomad
  - rsyslog
  - sleepylizard
  - supervisord
```

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

Then reference it by its fully-qualified name. To drop a service you don't run and
override another service's paths:

```yaml
- hosts: debian_hosts
  become: true
  vars:
    logrotate_services: "{{ logrotate_services | reject('equalto', 'jenkins') | list }}"
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

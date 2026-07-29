# ansible-role-logrotate

Installs `logrotate` and deploys a fixed set of `/etc/logrotate.d/` config
files for a specific list of services.

## Requirements

- Debian (or a Debian-based distribution)
- The play must run with `become: true`, since the role installs a package and
  writes to `/etc/logrotate.d`

## Role Variables

None. The `logrotate.d` configs (`files/logrotate.d/*`) are static files, not
templates, and are all copied to `/etc/logrotate.d/` unconditionally —
regardless of whether the corresponding service is actually installed on the
host. The included configs are for: `apache2`, `apt`, `cron`, `fail2ban`,
`heating`, `homeauto`, `homeautogit`, `jenkins`, `mongo`, `monitor`,
`mqttlogger`, `mysql-server`, `nodered`, `nomad`, `rsyslog`, `sleepylizard`,
`supervisord`. If you don't run one of these services, its logrotate config
is harmless but unused — fork the `files/` directory if you want a leaner set.

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
- hosts: debian_hosts
  become: true
  roles:
    - blacknell.ansible_roles.logrotate
```

## Testing

A minimal local test playbook is provided under `tests/`:

```bash
ansible-playbook -i tests/inventory tests/test.yml
```

## License

MIT

## Author Information

Paul Blacknell

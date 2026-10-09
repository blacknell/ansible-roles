# ansible-role-std_packages

Baseline host setup: sets the timezone, installs `/etc/profile.d` scripts
(Debian version banner, fail2ban status check), optionally pins apt
preferences, installs `git`/`rsync`/`unattended-upgrades`/`apt-listchanges`,
optionally installs `iperf3`, and configures how verbosely `cron` logs to
`/etc/default/cron`.

## Requirements

- Debian (or a Debian-based distribution)
- The play must run with `become: true`, since the role installs packages and
  writes to `/etc/profile.d`, `/etc/apt/preferences.d`, and `/etc/default/cron`

## Role Variables

| Variable                | Required | Default          | Description                                                        |
|--------------------------|----------|------------------|------------------------------------------------------------------------|
| `std_packages_timezone`               | No       | `Europe/London`  | std_packages_timezone name passed to the `std_packages_timezone` module                          |
| `std_packages_define_apt_preferences` | No       | `false`          | When `true`, installs the apt preference pin files under `files/apt/preferences.d` |
| `std_packages_install_iperf3`         | No       | `false`          | When `true`, installs the `iperf3` package                             |
| `std_packages_crond_log_processes`    | No       | `false`          | When `false`, sets `cron` to log only failed processes (`-L 4`); when `true`, logs all processes (`-L 5`) |

## Dependencies

None.

## Handlers

- `Restart crond` — triggered by the timezone and crond logging tasks

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
  vars:
    std_packages_timezone: Europe/London
    std_packages_define_apt_preferences: true
    std_packages_install_iperf3: true
  roles:
    - blacknell.ansible_roles.std_packages
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

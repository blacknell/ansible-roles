# ansible-role-timesync

Configures [systemd-timesyncd](https://www.freedesktop.org/software/systemd/man/latest/timesyncd.conf.html),
Debian's default time sync client, using a drop-in under
`/etc/systemd/timesyncd.conf.d/`. Replaces the old `ntp` role.

**This role always removes other time daemons.** `ntp`, `ntpsec`, `chrony` and
`openntpd` are purged (config included), and `/etc/ntp.conf` left by the old
`ntp` role is deleted. Don't apply it to hosts that serve time to other
machines; use chrony for those.

## Requirements

- Debian or a Debian-based distribution (including Raspberry Pi OS) with systemd.
  Tasks only run when `ansible_facts['os_family'] == 'Debian'`; other platforms
  such as macOS (which syncs time with its own `timed` service) are skipped
  rather than failed. Facts must be gathered (`gather_facts: true`, the default).
- Bookworm or later, where `systemd-timesyncd` is a separate package
- Not for LXC/containers: timesyncd won't start there by design, because the
  container's clock comes from the host

## Role Variables

| Variable                        | Required | Default                    | Description |
|---------------------------------|----------|----------------------------|-------------|
| `timesync_ntp_servers`          | No       | `0-3.pool.ntp.org`         | Servers for `NTP=`. Override with a regional pool, e.g. `0-3.uk.pool.ntp.org` |
| `timesync_fallback_ntp_servers` | No       | `[]`                       | Servers for `FallbackNTP=`. Empty keeps Debian's built-in `debian.pool.ntp.org` fallback |
| `timesync_dropin_name`          | No       | `50-ansible.conf`          | Drop-in file name. The prefix orders it after vendor drop-ins such as Raspberry Pi OS's `40-rpi-sync.conf` |

`vars/main.yml` holds the list of conflicting packages and legacy files that are
removed.

## Handlers

- `Restart timesyncd`: triggered when the drop-in changes

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
- hosts: virtual_machines
  become: true
  roles:
    - blacknell.ansible_roles.timesync
  vars:
    timesync_ntp_servers:
      - 0.uk.pool.ntp.org
      - 1.uk.pool.ntp.org
      - 2.uk.pool.ntp.org
      - 3.uk.pool.ntp.org
```

## Checking it on a host

```bash
systemd-analyze cat-config systemd/timesyncd.conf   # effective config incl. drop-ins
timedatectl timesync-status                         # current server, offset, poll interval
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

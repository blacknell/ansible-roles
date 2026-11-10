# ansible-role-update_debian

Brings a Debian host fully up to date: refreshes the apt cache, upgrades every
package (`dist-upgrade` by default), cleans up, and tells you if the host needs
a reboot. It can also do the reboot itself.

Other roles in this collection install packages with `state: present` and never
upgrade them, so this is the role that patches a host.

**Safe to run against a whole inventory.** Hosts that aren't Debian (e.g. Macs)
and hosts running openmediavault are skipped with a message, not failed.

## Requirements

- Debian or a Debian-based distribution. Other platforms are skipped.
- The play must run with `become: true`.
- If the play has `gather_facts: false`, the role gathers the minimal facts it
  needs to tell the OS family.

## Role Variables

| Variable                            | Required | Default | Description |
|-------------------------------------|----------|---------|-------------|
| `update_debian_cache_valid_time`    | No       | `3600`  | Refresh the apt cache first if it's older than this many seconds. `0` always refreshes |
| `update_debian_upgrade`             | No       | `dist`  | `dist` (`apt-get dist-upgrade`), `full` or `safe` (both need `aptitude`) |
| `update_debian_autoclean`           | No       | `true`  | Run `apt-get autoclean` |
| `update_debian_autoremove`          | No       | `true`  | Run `apt-get autoremove` (old kernels, orphaned dependencies) |
| `update_debian_skip_openmediavault` | No       | `true`  | Skip hosts with `openmediavault` installed, which manages its own updates |
| `update_debian_reboot`              | No       | `false` | Reboot when the upgrade leaves `/var/run/reboot-required` |
| `update_debian_reboot_timeout`      | No       | `600`   | With `update_debian_reboot`, seconds to wait for the host to come back and accept SSH before failing |

## Behaviour

- The apt cache is refreshed inside the role, so playbooks no longer need their
  own "update apt cache" `pre_task`.
- After upgrading, the role checks `/var/run/reboot-required`. If it's there,
  it prints the packages from `/var/run/reboot-required.pkgs` (a new kernel,
  libc, systemd, ...).
- **Reboots are off by default.** With `update_debian_reboot: false` you only
  get the message, and reboot when it suits you. Set it to `true` and the role
  reboots the host with `ansible.builtin.reboot`, waits up to
  `update_debian_reboot_timeout` seconds for it to come back, and carries on
  with the rest of the play. Hosts that don't need a reboot aren't rebooted.
- Upgrading Docker (`docker-ce`, `containerd`) restarts the Docker daemon and
  with it every container. For hosts serving sites, run the play with
  `serial: 1` so they're patched one at a time.
- `--check` reports what would be upgraded and never reboots.

## Dependencies

None.

## Example Playbooks

Report only, for any inventory:

```yaml
- hosts: all
  become: true
  roles:
    - role: blacknell.ansible_roles.update_debian
      tags: [update_debian]
```

Servers patched one at a time, rebooting when needed, stopping if one fails:

```yaml
- hosts: virtual_machines
  become: true
  serial: 1
  max_fail_percentage: 0
  vars:
    update_debian_reboot: true
  roles:
    - blacknell.ansible_roles.update_debian
```

This role is distributed as part of the `blacknell.ansible_roles` collection. Add it to
your `requirements.yml`:

```yaml
collections:
  - name: https://github.com/blacknell/ansible-roles.git
    type: git
    version: main
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

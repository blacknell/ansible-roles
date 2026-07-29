# ansible-role-ntp

Installs `ntp` and deploys a static `/etc/ntp.conf` configured to sync against
the UK `pool.ntp.org` servers.

## Requirements

- Debian (or a Debian-based distribution)
- The play must run with `become: true`, since the role installs a package and
  writes to `/etc/ntp.conf`

## Role Variables

None. The deployed `ntp.conf` (`files/ntp.conf`) is a static file, not a
template — the NTP pool servers (`0-3.uk.pool.ntp.org`) are hardcoded. If you
need different pool servers, fork the file rather than passing a variable.

## Dependencies

None.

## Handlers

- `Restart NTP` — triggered when `ntp.conf` changes

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
    - blacknell.ansible_roles.ntp
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

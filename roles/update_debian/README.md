# ansible-role-update_debian

Updates all apt packages to their latest version, dist-upgrades the OS, and cleans up
unused packages/cache (`apt-get update && dist-upgrade && autoclean && autoremove`).

## Requirements

- Debian (or a Debian-based distribution)
- The play must run with `become: true`, since the role installs/removes packages
  system-wide

## Role Variables

None. This role has no configurable variables — it always updates and upgrades
everything.

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
    - blacknell.ansible_roles.update_debian
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

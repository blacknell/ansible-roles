# ansible-role-syncthing

Installs [Syncthing](https://syncthing.net/) via Homebrew on macOS clients and keeps it
up to date, restarting the Homebrew service whenever a new version is installed.

## Requirements

- macOS — every task is gated on `ansible_facts['os_family'] == 'Darwin'` and is a no-op
  on any other platform
- [Homebrew](https://brew.sh/) already installed on the target
- The `community.general` collection (for the `community.general.homebrew` and
  `community.general.homebrew_services` modules) installed alongside this one:
  ```bash
  ansible-galaxy collection install community.general
  ```

## Role Variables

None.

## Dependencies

None (role dependencies) — see Requirements above for the `community.general` collection
dependency.

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
- hosts: macs
  roles:
    - blacknell.ansible_roles.syncthing
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

# ansible-role-python

Installs `git`, `python3-pip`, `python3-venv`, and `python3-debian` via apt — the baseline
needed to clone a repo and set up an isolated Python virtualenv on a Debian host.

## Requirements

- Debian (or a Debian-based distribution) — this role's only task is a plain `apt:`
  install, with no platform guard, so it will fail on any non-apt system

## Role Variables

None.

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
    - blacknell.ansible_roles.python
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

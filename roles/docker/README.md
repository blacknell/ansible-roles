# ansible-role-docker

Installs and configures [Docker CE](https://docs.docker.com/engine/) on Debian-based
hosts, from the official Docker apt repository, and enables the `docker.service` daemon.

## Requirements

- Debian (or a Debian-based distribution, e.g. Raspberry Pi OS)
- `aarch64` or `x86_64` architecture only — the role asserts this and fails fast otherwise
- Ansible core >= 2.15 (uses the `ansible.builtin.deb822_repository` module)
- The play must run with `become: true`, since the role installs packages and manages
  the systemd service

## Role Variables

| Variable         | Required | Default | Description                                                                 |
|-------------------|----------|---------|-------------------------------------------------------------------------------|
| `linux_user_id`   | Yes      | none    | Local user to add to the `docker` group, so it can run `docker` without `sudo` |

`linux_user_id` has no default and must be set by the consuming playbook or inventory
(e.g. in `group_vars`), or the role will fail on the "Add user to 'docker' group" task.

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
- hosts: docker_hosts
  become: true
  vars:
    linux_user_id: pi
  roles:
    - blacknell.ansible_roles.docker
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

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

| Variable | Default | Description |
|---|---|---|
| `docker_users` | `[]` | Users added to the `docker` group so they can run `docker` without `sudo`. Empty means just `linux_user_id` |
| `linux_user_id` | none | Used when `docker_users` is empty; must then be set by the consuming playbook or inventory |
| `docker_daemon_options` | `{}` | Written to `/etc/docker/daemon.json` when not empty, after `dockerd --validate` checks it. Changing it restarts Docker. Left empty, an existing `daemon.json` is not touched |

Docker is only restarted when the engine packages or `daemon.json` change, not when the
dependencies or the apt repository change.

When users are added to the group, the role resets the connection so later tasks in the
same play can run `docker` as them.

Example `daemon.json` settings, with container log rotation and `live-restore` so
containers keep running while the daemon restarts:

```yaml
docker_daemon_options:
  log-driver: json-file
  log-opts:
    max-size: "10m"
    max-file: "3"
  live-restore: true
```

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
    docker_users: [pi]
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

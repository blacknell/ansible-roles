# ansible-role-btop

Installs [btop](https://github.com/aristocratos/btop) — via apt on Debian, via Homebrew on
macOS.

## Requirements

- Debian (or a Debian-based distribution), where the apt install task runs when
  `ansible_facts['distribution'] == 'Debian'`, **or**
- macOS, where the Homebrew install task runs when
  `ansible_facts['os_family'] == 'Darwin'`
  - [Homebrew](https://brew.sh/) must already be installed on the target
  - The `community.general` collection (for the `community.general.homebrew` module)
    installed alongside this one:
    ```bash
    ansible-galaxy collection install community.general
    ```

## Role Variables

None.

## Dependencies

None (role dependencies) — see Requirements above for the `community.general` collection
dependency needed on macOS.

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
- hosts: workstations
  become: true
  roles:
    - blacknell.ansible_roles.btop
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

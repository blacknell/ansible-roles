# ansible-role-fzf

Installs [fzf](https://github.com/junegunn/fzf) via apt and adds its bash key bindings
(`Ctrl-R`, `Ctrl-T`, etc.) to the connecting user's `.bashrc`.

## Requirements

- Debian (or a Debian-based distribution) — the package install task only runs when
  `ansible_facts['distribution'] == 'Debian'`
- The `fzf` apt package must ship `/usr/share/doc/fzf/examples/key-bindings.bash`
  (true for Debian's packaged fzf)

## Role Variables

None of this role's own. It relies on the built-in `ansible_user` magic variable
(set from the connection/`remote_user`) to know whose `~/.bashrc` to edit.

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
- hosts: workstations
  become: true
  roles:
    - blacknell.ansible_roles.fzf
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

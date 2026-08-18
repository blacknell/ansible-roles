# ansible-role-fzf

Installs [fzf](https://github.com/junegunn/fzf) — via apt on Debian, via Homebrew on
macOS — and wires up its shell key bindings (`Ctrl-R`, `Ctrl-T`, etc.) in the connecting
user's `.bashrc`/`.zshrc`.

Key bindings are installed using fzf's own `eval "$(fzf --bash)"` / `source <(fzf --zsh)`
integration rather than sourcing a static `key-bindings.*` file, since that file's location
varies by package manager (and, on macOS, by Homebrew prefix — `/opt/homebrew` on Apple
Silicon vs `/usr/local` on Intel). Asking the `fzf` binary to print its own integration
script sidesteps that entirely.

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
- A login shell of `bash` or `zsh` (detected via `ansible_facts['user_shell']`) — other
  shells are skipped

## Role Variables

None of this role's own. It relies on the standard `ansible_facts['user_dir']` and
`ansible_facts['user_shell']` facts (re-gathered as the connecting user, not
become-escalated) to know whose dotfiles to edit and which shell block to install.

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

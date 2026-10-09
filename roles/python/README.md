# ansible-role-python

Python baseline across Debian and macOS. Safe to include in any play - each platform gets
its own tasks and anything else fails fast with a clear message.

| Platform | What it does |
|----------|--------------|
| Debian   | Installs distro `python3` with `git`, `python3-pip`, `python3-venv`, `python3-debian`, `python3-apt` via apt |
| macOS    | Installs/upgrades Homebrew `python@3.14` and makes it the one default `python`, `python3`, `pip`, `pip3` |

Re-running the role is how Python is kept patched: apt `latest` on Debian, `brew update` +
upgrade on macOS.

## macOS behaviour

Every run (tag `python`):
- installs/upgrades `python@<python_macos_version>` and removes superseded kegs
- when `python_manage_shell` is true:
  - strips pyenv init and python.org installer PATH lines from `~/.zshrc` / `~/.zprofile` (backups kept)
  - adds `<brew prefix>/opt/python@3.14/libexec/bin` to PATH in `~/.zprofile`
  - asserts a new login shell resolves `python3` to brew Python
- lists project venvs under `python_venv_search_paths` not built on the stable brew path

One-off, only with `--tags python_cleanup` (tagged `never`):
- uninstalls pyenv and deletes `~/.pyenv`
- deletes the python.org install (`/Library/Frameworks/Python.framework`,
  `/Applications/Python 3.x`, its `/usr/local/bin` links) - needs `--ask-become-pass`
- uninstalls other brew `python@3.x` formulae that nothing depends on

Homebrew tasks always run with `become: false`, so the role works under plays that set
`become: true`.

### Venvs and PyCharm

Build venvs from the stable `opt` path, never `/opt/homebrew/bin/python3` (which resolves
into a versioned `Cellar` folder that is deleted on the next patch upgrade):

```
/opt/homebrew/opt/python@3.14/bin/python3.14
```

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `python_debian_packages` | git, python3-venv, python3-pip, python3-debian, python3-apt | apt packages on Debian |
| `python_macos_version` | `"3.14"` | Homebrew `python@` version to make the default |
| `python_brew_prefix` | `/opt/homebrew` (arm64) or `/usr/local` | Homebrew prefix |
| `python_update_homebrew` | `true` | Run `brew update` first |
| `python_manage_shell` | `true` | Edit `~/.zshrc` / `~/.zprofile` |
| `python_venv_search_paths` | `~/GitHub` | Where to look for venvs to report on |
| `python_venv_search_depth` | `4` | Search depth for the above |
| `python_cleanup_pyenv` | `true` | Cleanup: remove pyenv |
| `python_cleanup_python_org` | `true` | Cleanup: remove python.org install |
| `python_cleanup_unused_brew` | `true` | Cleanup: remove brew Pythons with no dependents |

## Dependencies

`community.general` (Homebrew module).

## Example Playbook

```yaml
- hosts: macs
  roles:
    - blacknell.ansible_roles.python

- hosts: raspberries
  become: true
  roles:
    - blacknell.ansible_roles.python
```

```bash
ansible-playbook macs.yml --tags python
ansible-playbook macs.yml --tags python_cleanup --ask-become-pass   # once, after rebuilding venvs
```

## Testing

```bash
ansible-playbook -i tests/inventory tests/test.yml
```

## License

MIT

## Author Information

Paul Blacknell

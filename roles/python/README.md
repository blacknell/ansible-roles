# ansible-role-python

Python baseline across Debian and macOS. Safe to include in any play - each platform gets
its own tasks and anything else fails fast with a clear message.

| Platform | What it does |
|----------|--------------|
| Debian   | Installs `git`, `python3-pip`, `python3-venv`, `python3-debian`, `python3-apt` (and with them the distro `python3`) via apt |
| macOS    | Installs/upgrades Homebrew `python@3.14` and makes it the one default `python`, `python3`, `pip`, `pip3` |

On Debian packages are installed `present`; keeping them patched is left to normal apt
upgrades (e.g. the `update_debian` role). On macOS every run does `brew update` and
upgrades the formula, so re-running the role is how brew Python is kept patched.

## Tags

Every task is tagged `python`, so `--tags python` runs the whole role whether or not the
calling playbook tags it, and `--tags <other role>` never runs any of it. Nothing in the
role is tagged `always` or `never`.

## macOS behaviour

Every run:
- installs/upgrades `python@<python_macos_version>` and removes superseded kegs
- when `python_manage_shell` is true:
  - strips pyenv init and python.org installer PATH lines from `~/.zshrc` / `~/.zprofile` (backups kept)
  - adds `<brew prefix>/opt/python@3.14/libexec/bin` to PATH in `~/.zprofile`
  - asserts a new zsh login shell resolves `python`, `python3` and `pip` to brew Python
- when `python_venv_search_paths` is set, lists project venvs there that aren't built on
  the stable brew path

Normal runs never need sudo: Homebrew and your shell files are handled as the connecting
user (`become: false`), even under a `become: true` play.

### Cleanup (one-off, opt-in)

For a Mac moving to brew Python from pyenv or the python.org installer. Rebuild your
project venvs on brew Python first: any built on a Python this removes stops working.

```bash
ansible-playbook macs.yml --tags python -e python_cleanup=true --ask-become-pass
```

With `python_cleanup: true` the role also:
- uninstalls pyenv and deletes `~/.pyenv`
- deletes the python.org install (`/Library/Frameworks/Python.framework`,
  `/Applications/Python 3.x`, its `/usr/local/bin` links). This needs sudo, so add
  `--ask-become-pass` if your sudo needs a password. The role checks sudo works before
  removing anything and stops with a clear message if it doesn't.
- uninstalls other brew `python@3.x` formulae that nothing depends on

Each part can be turned off with the `python_cleanup_*` variables below. Cleanup does
nothing on Debian.

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
| `python_venv_search_paths` | `[]` | Folders to search for venvs to report on; relative paths are under the user's home, e.g. `["GitHub"]`. Empty skips the search |
| `python_venv_search_depth` | `4` | Search depth for the above |
| `python_cleanup` | `false` | Run the one-off macOS cleanup |
| `python_cleanup_pyenv` | `true` | Cleanup: remove pyenv |
| `python_cleanup_python_org` | `true` | Cleanup: remove python.org install |
| `python_cleanup_unused_brew` | `true` | Cleanup: remove brew Pythons with no dependents |

## Requirements and limitations

- ansible-core 2.16 or later.
- `community.general` (Homebrew module).
- Debian: apt needs root, so run the role in a play with `become: true` (or as root).
- macOS: Homebrew must already be installed at `python_brew_prefix`; the role doesn't
  install it.
- macOS: shell management and the verify step only cover zsh (`~/.zshrc`,
  `~/.zprofile`), the macOS default. With another login shell set
  `python_manage_shell: false` and put brew Python on PATH yourself.
- macOS: the verify step starts an interactive zsh login shell (`zsh -lic`). Shell
  start-up that prompts for input (e.g. an oh-my-zsh update prompt) can hang the run.

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
ansible-playbook site.yml --tags python
ansible-playbook macs.yml --tags python -e python_cleanup=true --ask-become-pass   # once, after rebuilding venvs
```

## Testing

```bash
ansible-playbook -i tests/inventory tests/test.yml
```

## License

MIT

## Author Information

Paul Blacknell

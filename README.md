# ansible-roles

A shared collection of reusable, standalone Ansible roles, packaged as the
`blacknell.ansible_roles` Ansible Collection.

## Usage

Add this repo as a collection source in your playbook repo's `requirements.yml`:

```yaml
collections:
  - name: https://github.com/blacknell/ansible-roles.git
    type: git
    version: main
```

Install it:

```bash
ansible-galaxy install -r requirements.yml
```

Reference a role by its fully-qualified name in your playbook:

```yaml
- hosts: docker_hosts
  become: true
  vars:
    linux_user_id: pi
  roles:
    - blacknell.ansible_roles.docker
```

Or declare the collection once at the play level and use short names:

```yaml
- hosts: docker_hosts
  become: true
  collections:
    - blacknell.ansible_roles
  vars:
    linux_user_id: pi
  roles:
    - docker
```

## Updating

`ansible-galaxy install` only downloads a collection the first time. Pushing new
commits to this repo does **not** automatically update anyone using it — each
consumer has to explicitly ask for the update.

1. Push your changes to `ansible-roles` as normal.
2. On any machine consuming this collection, re-run install with `--force`:
   ```bash
   ansible-galaxy install -r requirements.yml --force
   ```
   Without `--force`, Ansible sees the collection is already installed and does
   nothing, even if `main` has moved on.
3. That's it — the next playbook run uses the updated role(s).

### Pinning a version (recommended for anything beyond your own homelab)

Tracking `version: main` means "whatever main looked like the moment I last
force-installed it" — convenient, but not reproducible.

For a stable, repeatable setup, tag releases in this repo and pin to a tag instead:

1. In `ansible-roles`, once changes are ready to ship:
   ```bash
   git tag v1.1.0
   git push origin v1.1.0
   ```
2. In the consuming repo's `requirements.yml`, point at the tag instead of `main`:
   ```yaml
   collections:
     - name: https://github.com/blacknell/ansible-roles.git
       type: git
       version: v1.1.0
   ```
3. Install/update as usual:
   ```bash
   ansible-galaxy install -r requirements.yml --force
   ```
4. To pick up a later change, bump the tag in `requirements.yml` to the new
   version and re-run install. Nothing changes for consumers until you do this
   — updates are always a deliberate, manual step, never automatic.

## Roles

| Role     | Description                                  |
|----------|-----------------------------------------------|
| [docker](roles/docker) | Installs Docker CE from the official apt repo |

## License

MIT

# Changelog

All notable changes to the `blacknell.ansible_roles` collection.

## 1.9.0

### Changed

- docker: only restart Docker when the engine packages or `daemon.json` change, not when its dependencies or apt repository change
- docker: no longer installs `gnupg`, `python3-cffi` or `python3-cryptography`, which the deb822 repository doesn't need (already-installed copies are left alone)

### Added

- docker: `docker_daemon_options` writes `/etc/docker/daemon.json`, validated with `dockerd --validate`
- docker: `docker_users` list for the `docker` group (defaults to `linux_user_id`), with a connection reset when users are added
- docker: `docker_packages_state` (default `present`) for the engine packages
- docker: remove conflicting distro packages (`docker.io`, `podman-docker`, `containerd`, `runc`, ...) before install, set by `docker_obsolete_packages`
- docker: remove old-style Docker repo files that conflict with the deb822 source
- docker: `--check` no longer fails on hosts without Docker installed

## 1.8.0

### Fixed

- timesync: skip the role on non-Debian hosts instead of failing
- timesync: skip the role on openmediavault hosts to avoid removing OMV
- docker: refresh the apt cache in the engine install task instead of a separate when-changed task
- Install packages with `state: present` instead of `latest`, so runs no longer upgrade packages as a side effect
- update_debian: remove the redundant `name: "*"` latest task (`upgrade: dist` covers it)
- user: set explicit file permissions

### Changed

- Use FQCNs for all module actions
- Lint with the `production` profile
- Add `meta/runtime.yml` and this changelog

## 1.7.0

Changelog started after this release. For 1.7.0 and earlier, see the git history.

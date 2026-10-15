# Changelog

All notable changes to the `blacknell.ansible_roles` collection.

## Unreleased

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

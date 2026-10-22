# Changelog

All notable changes to the `blacknell.ansible_roles` collection.

## Unreleased

### Fixed

- nginx_proxy: a copied-in certificate first issued with another plugin (e.g. apache) has no webroot settings, so switching its renewal config to webroot left renewal with nowhere to put the challenge. The role now adds `webroot_path` and a `[[webroot_map]]` for the certificate's domains when they're missing, as well as rewriting them when they point elsewhere

## 1.12.0

### Added

- swap: new role. Adds a swap file (`fallocate`, `mkswap`, fstab) and sets `vm.swappiness` on Debian hosts that set `swap_file_size_mb`; off by default so it can run on every host. Skips hosts where `dphys-swapfile` manages swap, and reports rather than resizes a swap file of a different size

## 1.11.0

### Added

- apache_app: new role. A PHP application under Apache in Docker Compose serving one or more vhosts from one web container (`php:8.3-apache` by default, `mod_remoteip`, `.htaccess`), published on `127.0.0.1` for a reverse proxy, with an optional MySQL container on an internal network. Database users and grants on every run, `db_import` for a `.sql`/`.sql.gz` dump, nightly gzipped backups and logrotate
- nginx_proxy: `redirect_to` on a site, instead of `upstream`, to 301 every request to another host (e.g. a bare domain to `www`), keeping the path

## 1.10.0

### Added

- nginx_proxy: new role. nginx reverse proxy on the host from the distro package, vhosts from `nginx_proxy_sites`. A site's HTTPS server is only written once its certificate exists, so a missing certificate can't stop nginx for the other sites. Sets `nginx_proxy_certbot_certs` for geerlingguy.certbot, installs a deploy hook that reloads nginx after renewal, and points copied-in certificates' renewal configs at its ACME folder
- jenkins_docker: `restore` entry point (`--tags restore`) restores a `jenkins-home-*.tar.gz` backup into the volume, after checking the tarball reads cleanly

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

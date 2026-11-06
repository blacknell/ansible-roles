# Changelog

All notable changes to the `blacknell.ansible_roles` collection.

## Unreleased

### Added

- msmtp: new role. Installs msmtp as the host's sendmail, relaying through an SMTP server. Moved from blacknell/ansible, with every setting a variable and no ties to other roles
- nftables_blocklist: new role. Loads FireHOL levels 1-4 and AbuseIPDB's blacklist into nftables on a cron schedule. Moved from blacknell/ansible's `firehol` role (variables renamed from `firehol_*`), with sources, schedules and limits as variables

### Fixed

- nftables_blocklist: after a reboot, FireHOL lists are reloaded on their next run. Before, a run whose ETag or content hash matched the last one exited as unchanged without re-creating the table, so the list stayed unloaded until upstream changed

## 1.17.0

### Changed

- fail2ban: install bind9-dnsutils so the fail2ban apt task doesn't report changed on Debian 13
- fail2ban: the MQTT action (`action.d/mqtt-notify.conf`) is only installed when `fail2ban_mqtt_enabled` is true, and removed otherwise. Earlier versions installed it on every host, with an empty broker host and user where MQTT was off

## 1.16.0

### Changed

- python: `python_macos_version` has no default and must be set on macOS, as a quoted string such as `"3.14"`. The role stops with a message if it's missing or unquoted (unquoted `3.10` is read as `3.1`). A collection upgrade no longer changes which Python a Mac uses
- python: the macOS cleanup (remove pyenv, the python.org install and unused brew Pythons) is turned on with `python_cleanup: true` instead of `--tags python_cleanup`. Running with `--tags python_cleanup` now stops with a message saying what to use instead
- python: `python_venv_search_paths` defaults to `[]`, which skips the venv report (was `~/GitHub`). Relative paths are under the user's home, e.g. `["GitHub"]`
- python: needs ansible-core 2.16 or later

### Fixed

- python: every task is tagged `python` and none `always` or `never`. `--tags python` runs the role whether or not the playbook tags it, other roles' `--tags` no longer run its setup tasks, and a playbook tagging the role `python` no longer makes `--tags python` run the cleanup
- python: works in plays with `gather_facts: false`
- python: no longer re-gathers facts, which changed `ansible_facts` for roles run after it
- python: venvs built from Homebrew's `libexec/bin/python` are no longer reported as needing a rebuild
- logrotate: `nomad.log` is rotated with `copytruncate`, so Nomad keeps logging after a rotation
- The collection build no longer includes the local `.ansible/` and `.idea/` folders

## 1.15.1

### Changed

- fail2ban: `fail2ban_mqtt_host`, `fail2ban_mqtt_port` and `fail2ban_mqtt_user` no longer have site-specific defaults. Hosts with `fail2ban_mqtt_enabled` must set the host and user (the role stops with a message if they're empty); an empty port uses mosquitto's default, 1883

### Removed

- fail2ban: the Home Assistant (`hass`) jail and its filter, along with `fail2ban_hass_jail_enabled` and `fail2ban_hass_logpath`. Home Assistant no longer writes the log file it read. The role removes `/etc/fail2ban/filter.d/hass.conf` from hosts it installed it on

## 1.15.0

### Added

- fail2ban: new role, moved from the blacknell/ansible repo. fail2ban with nftables bans, an `sshd` jail, and Apache, Joomla, repeat-offender (recidive), Home Assistant and Frigate jails that are each switched on by a variable. Bans can be reported to AbuseIPDB and IPThreat, posted to Slack (webhook per ban, bot for repeat offenders and a cron'd summary) and MQTT, and sent as X-ARF abuse emails; each is only added to the jails when its secret or setting is set. Secrets are read from controller environment variables by default (`op run`), or can be set directly. Ships its own `reload fail2ban` handlers, which validate the config with `fail2ban-client -t` before restarting

## 1.14.0

### Added

- apache_app: `apache_app_web_healthcheck` gives the web container a Docker health check. `curl` inside the container (it's in the official php images) requests `apache_app_web_healthcheck_path` (default `/`) with the first vhost's name; any 2xx or 3xx answer is healthy, so a PHP app that can't reach its database shows as unhealthy, and the playbook's compose step waits for it. The checks are left out of the access logs. Off by default

## 1.13.1

### Fixed

- nginx_proxy: basic-auth passwords no longer appear in the output when a task fails. A failed loop item is printed in full, and the site list every task loops over carried the passwords; it now holds only user names, and the passwords are read only by `no_log` tasks. The htpasswd file is also left out of `--diff` output
- nginx_proxy: `--check` no longer fails at "Enable each present site" for a site added in the same run, whose vhost check mode doesn't write
- apache_app: `--check` on a new app no longer fails at "Build and start the containers"; the compose step is skipped until the project exists (#17)

## 1.13.0

### Added

- apache_app: `apache_app_html_writable` mounts `html/` read-write and makes each docroot owned by the container's `www-data` (uid 33), for apps that write their own files such as WordPress. Off by default, so existing apps keep read-only docroots
- apache_app: `apache_app_php_extension_installer` builds `apache_app_php_extensions` with mlocati's `install-php-extensions`, which adds each extension's build packages and configure options (`gd` with JPEG/WebP/FreeType, `intl`, `zip`) and installs PECL extensions such as `imagick`
- apache_app: `apache_app_wp_cli` installs WP-CLI (`apache_app_wp_cli_version`, default 2.12.0) as `/usr/local/bin/wp`
- nginx_proxy: `auth` on a site puts its HTTPS server behind basic auth (`users`, hashed with `openssl passwd -6` into `/etc/nginx/htpasswd/<name>`) with an `allow` list of addresses let in without a password. The `Authorization` header isn't passed upstream, so apps that read it (WordPress application passwords) don't reject the nginx login. Removing the key opens the site up and its password file is removed after the reload

## 1.12.1

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

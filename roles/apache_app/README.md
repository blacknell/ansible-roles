# ansible-role-apache_app

A PHP application under Apache in Docker Compose, serving one or more sites (vhosts) from
one web container, with an optional MySQL database that only that container can reach.
Built for moving sites off an old host where several related sites (say `www`, `beta` and
`scratch` of one app) shared Apache and a database.

- **Web container**: built on `apache_app_php_image` (default `php:8.3-apache`) with the
  PHP extensions and Apache modules you list, `php.ini-production`, and `mod_remoteip`. It
  publishes only `127.0.0.1:<apache_app_port>`, for a reverse proxy on the host (e.g.
  `nginx_proxy`) that sends every site's name to that port. Apache picks the vhost from the
  `Host` header.
- **Sites**: each vhost has its own document root under `html/`, logs, and optional
  `SetEnv` values. `.htaccess` files work (`AllowOverride All`).
- **Database** (`apache_app_db: true`): a MySQL container on an internal network with no
  route out and no published port. The app connects to host `db`. Users and grants are
  applied on every run, so password changes take effect.
- **Behind a proxy**: `mod_remoteip` takes the client address from `X-Forwarded-For`, so the
  logs and `$_SERVER['REMOTE_ADDR']` show real clients, and `X-Forwarded-Proto: https`
  sets `HTTPS=on` for PHP.
- **Imports and backups**: `db_import` loads a `.sql`/`.sql.gz` dump (e.g. from the old
  host); a nightly `mysqldump` keeps gzipped dumps in `backups/`.

## Layout

```
<apache_app_dir>/
├── docker-compose.yml
├── web.env, db.env      0600 root: container environment and database passwords
├── web/                 Dockerfile and app.ini (image build context)
├── apache/              app.conf (server-wide) and sites/vhosts.conf
├── html/<docroot>/      one document root per vhost, owned by apache_app_user
├── logs/                apache/<site>-access.log, <site>-error.log, and app log files
└── backups/             <name>-db-<stamp>.sql.gz (0700 root)
```

## Requirements

- Linux host with Docker and the Compose plugin, `flock`, `gzip` and GNU coreutils
- sudo; the tasks escalate as needed
- Ansible core >= 2.15 and the `community.docker` collection

## Role Variables

### Required

| Variable | Description |
|---|---|
| `apache_app_name` | Short lower-case name: compose project, containers `<name>-web` / `<name>-db`, files |
| `apache_app_user` | User that owns the compose project and document roots |
| `apache_app_dir` | Folder for everything above |
| `apache_app_port` | Port published on `127.0.0.1` |
| `apache_app_vhosts` | The sites (see below) |

With `apache_app_db: true`, also `apache_app_db_password` and `apache_app_db_root_password`.

### Sites

| Key | Default | Description |
|---|---|---|
| `server_name` | required | `ServerName` |
| `aliases` | `[]` | `ServerAlias` names |
| `docroot` | `server_name` | Folder under `html/` |
| `env` | `{}` | `SetEnv` for this site only. A value can be `${VAR}` to read `VAR` from `apache_app_env`, so a secret only one site needs stays in the env file |
| `extra_config` | `""` | Raw Apache lines for this `<VirtualHost>` |

The first vhost Apache sees is a built-in default that returns 404 for unknown names.

### Web container

| Variable | Default | Description |
|---|---|---|
| `apache_app_php_image` | `php:8.3-apache` | Base image |
| `apache_app_php_extensions` | `[]` | Built in with `docker-php-ext-install`, e.g. `[pdo_mysql, mysqli]` |
| `apache_app_apt_packages` | `[]` | Debian packages some extensions need to build |
| `apache_app_apache_modules` | `[rewrite, headers]` | Modules to enable; `remoteip` is always added |
| `apache_app_php_ini` | `{expose_php: "Off"}` | Settings on top of `php.ini-production` |
| `apache_app_env` | `{}` | Environment for the web container (all sites), in a 0600 env file. Values can't contain `'` or a newline |
| `apache_app_log_files` | `[]` | Log files the app writes inside the container, e.g. `[/var/log/myapp.log]`, bind-mounted from `logs/` |
| `apache_app_restart_policy` | `unless-stopped` | Compose restart policy |

### Database

| Variable | Default | Description |
|---|---|---|
| `apache_app_db` | `false` | Run the MySQL container |
| `apache_app_db_image` | `mysql:8.4` | Image |
| `apache_app_db_name` | `apache_app_name` | Database |
| `apache_app_db_user` | `apache_app_name` | App user, with all privileges on the database |
| `apache_app_db_password` / `apache_app_db_root_password` | required | Passwords |
| `apache_app_db_extra_users` | `[]` | `{name, password, grants: ["SELECT ON db.table", ...]}`. A table-level grant is skipped, with a message, until the table exists, and applied after `db_import` |
| `apache_app_db_import_file` | `""` | `.sql` or `.sql.gz` on the host, for `db_import` |
| `apache_app_db_import_force` | `false` | Drop existing tables and import |
| `apache_app_db_backup` | `true` | Install the nightly backup |
| `apache_app_db_backup_dir` | `<apache_app_dir>/backups` | Where dumps go |
| `apache_app_db_backup_keep_days` | `14` | Dumps older than this are deleted |
| `apache_app_db_backup_min_bytes` | `1024` | A smaller dump fails the backup |
| `apache_app_db_backup_cron` / `_hour` / `_minute` | `true` / `"2"` / `"45"` | Schedule (root's crontab) |
| `apache_app_db_backup_script` / `_log` | `/usr/local/bin/<name>-db-backup` / `/var/log/<name>-db-backup.log` | Script and log |

### Logs

| Variable | Default | Description |
|---|---|---|
| `apache_app_logrotate` | `true` | `/etc/logrotate.d/<name>` for the Apache and app logs (`copytruncate`, since app log files are bind-mounted) and the backup log |
| `apache_app_logrotate_rotate` | `14` | Daily logs kept |

## Entry Points

| Entry point | Tag (via `main`) | What it does |
|---|---|---|
| `main` | | Folders, image, Apache config, env files, compose file; builds when the build files change, starts the containers and waits for them to be healthy; tests and reloads Apache when its config changed; database users and grants; backup script and cron; logrotate |
| `db_import` | `db_import` | Checks the dump (gzip test), refuses a database that has tables unless forced, imports it, shows the tables and row counts, and re-applies users and grants |
| `backup_now` | `backup_now` | Runs the installed backup and shows its output |

## Moving an app from another host

```bash
# on the old host
mysqldump --single-transaction --routines --triggers --no-tablespaces --set-gtid-purged=OFF -uroot -p myapp | gzip > myapp.sql.gz
# copy it to the new host, then
ansible-playbook -i inventory myapp.yml --tags db_import -e apache_app_db_import_file=/home/me/myapp.sql.gz
```

Copy the site files into `html/<docroot>/` (or deploy them), add the names to your reverse
proxy pointing at `http://127.0.0.1:<apache_app_port>`, test with `curl --resolve`, then move
DNS.

## Example Playbook

```yaml
- hosts: webservers
  vars:
    apache_app_name: myapp
    apache_app_user: paul
    apache_app_dir: /home/paul/sites/myapp
    apache_app_port: 8101
    apache_app_php_extensions: [pdo_mysql, mysqli]
    apache_app_env:
      DB_DSN: "mysql:host=db;dbname=myapp"
      DB_PASSWORD: "{{ lookup('ansible.builtin.env', 'MYAPP_DB_PASSWORD') }}"
      MAPS_KEY_WWW: "{{ lookup('ansible.builtin.env', 'MYAPP_MAPS_KEY') }}"
    apache_app_vhosts:
      - server_name: www.example.com
        env:
          MAPS_KEY: "${MAPS_KEY_WWW}"
      - server_name: beta.example.com
    apache_app_db: true
    apache_app_db_password: "{{ lookup('ansible.builtin.env', 'MYAPP_DB_PASSWORD') }}"
    apache_app_db_root_password: "{{ lookup('ansible.builtin.env', 'MYAPP_DB_ROOT_PASSWORD') }}"
  roles:
    - blacknell.ansible_roles.apache_app
```

## Testing

```bash
ansible-playbook -i tests/inventory tests/test.yml --syntax-check
```

## License

MIT

## Author Information

Paul Blacknell

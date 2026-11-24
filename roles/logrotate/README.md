# ansible-role-logrotate

Installs `logrotate`, optionally sets its global defaults in `/etc/logrotate.conf`, and
writes `/etc/logrotate.d/<name>` files through one shared task, `entry`.

The role doesn't keep a list of services. The files Debian packages ship (apt, rsyslog,
fail2ban, nginx, …) are left as they are, and each role or playbook that creates a log
writes that log's rotation itself, by calling `entry`:

- **Roles in this collection** do it for their own logs: `apache_app`, `msmtp` and
  `jenkins_docker`, each with `<role>_logrotate_*` variables for the interval and the
  number kept.
- **Your playbooks** do it for logs no role looks after, either with `logrotate_entries`
  or by calling `entry` next to the task that creates the log.

## Requirements

- Debian (or a Debian-based distribution): the role uses `dpkg-query` and `dpkg-divert`
- `become: true`, or root

## Role Variables

### Global defaults (`/etc/logrotate.conf`)

Off by default, so Debian's file is left alone. Turned on, Debian's copy is moved to
`/etc/logrotate.conf.disabled` with `dpkg-divert` (so upgrades don't ask about it) and
this role writes its own. Turned back off, Debian's copy is restored. The defaults are
Debian's own values.

These settings apply to every file in `/etc/logrotate.d` that doesn't set its own,
the package files included. `logrotate_global_dateext: true` is the way to get date
stamps on every log.

| Variable | Default | Description |
|---|---|---|
| `logrotate_package_state` | `present` | `present` or `latest` |
| `logrotate_global_manage` | `false` | Write `/etc/logrotate.conf` from the settings below |
| `logrotate_global_frequency` | `weekly` | `daily`, `weekly`, `monthly` or `yearly` |
| `logrotate_global_rotate` | `4` | Rotated logs kept |
| `logrotate_global_create` | `true` | Create a new empty log after rotating, with the old one's owner and mode |
| `logrotate_global_compress` | `false` | Compress rotated logs |
| `logrotate_global_dateext` | `false` | Name rotated logs by date (`syslog-20261124`) rather than number (`syslog.1`) |
| `logrotate_global_su` | `""` | Global `su`, e.g. `root adm` |
| `logrotate_global_options` | `[]` | Extra global directives |

### Entries (`/etc/logrotate.d`)

| Variable | Default | Description |
|---|---|---|
| `logrotate_entries` | `[]` | Entries to write, each with the keys below |
| `logrotate_remove` | `[]` | Names in `/etc/logrotate.d` to clean up, see [Migrating from 1.x](#migrating-from-1x) |

## The `entry` task

Writes, or removes, one `/etc/logrotate.d/<name>`. Set `logrotate_entry` and include it:

```yaml
- name: Rotate heating.log
  ansible.builtin.include_role:
    name: blacknell.ansible_roles.logrotate
    tasks_from: entry
  vars:
    logrotate_entry:
      name: heating
      paths: [/var/log/heating.log]
      frequency: monthly
      rotate: 12
      create: "640 pi adm"
```

`logrotate_entries` items take exactly the same keys.

| Key | Default | Description |
|---|---|---|
| `name` | required | File name in `/etc/logrotate.d` |
| `paths` | required when present | Logs or globs |
| `frequency` | `weekly` | `daily`, `weekly`, `monthly` or `yearly` |
| `rotate` | `4` | Rotated logs kept |
| `compress` / `delaycompress` | `true` / `true` | |
| `missingok` / `notifempty` | `true` / `true` | |
| `sharedscripts` | `true` | Run the scripts once for all the paths |
| `copytruncate` | `false` | Copy and truncate in place, for logs a process keeps open (bind-mounted files, supervisor). Not with `create` |
| `create` | `""` | e.g. `"640 www-data adm"`. Empty inherits the global setting |
| `su` | `""` | e.g. `"pi pi"`, for logs in folders root doesn't own |
| `dateext` | inherit | `true` or `false` to override the global setting |
| `prerotate` / `postrotate` | `""` | Shell, e.g. `docker exec myapp-web apache2ctl graceful` |
| `options` | `[]` | Extra directives |
| `body` | `""` | Everything between the braces, used as it is in place of all the settings above |
| `replaces_package_file` | `false` | See below |
| `state` | `present` | `absent` removes the file |

Each file is checked with `logrotate -d` before it's installed (a log that doesn't exist
yet isn't an error), and afterwards the whole config is loaded again to catch a log that
two files both rotate.

### Changing a file a Debian package ships

`logrotate` can't merge two files: if two files rotate the same log, it rotates it once
and reports an error. So to change, say, how long fail2ban's logs are kept, you replace
the package's file:

```yaml
logrotate_entries:
  - name: fail2ban
    paths: [/var/log/fail2ban.log]
    frequency: monthly
    rotate: 12
    create: "640 root adm"
    postrotate: fail2ban-client flushlogs 1>/dev/null
    replaces_package_file: true
```

The package's copy is moved to `/etc/logrotate.d/fail2ban.disabled` with `dpkg-divert`
(logrotate ignores `*.disabled`), and package upgrades update that copy rather than
asking about yours. With `state: absent`, yours is deleted and the package's copy moved
back. Without `replaces_package_file: true`, writing over a package's file fails with a
message saying so. If writing the new file fails, the package's copy is put back.

## Migrating from 1.x

1.x wrote a fixed list of files (`apache2`, `apt`, `cron`, `fail2ban`, `rsyslog`, and
others you turned on), several of them over the files Debian packages ship. 2.0 has no
`logrotate_services`, `logrotate_services_override`, `logrotate_<service>_paths` or
`logrotate_<service>_options`.

1. List the names 1.x wrote on a host in `logrotate_remove` for one run:

   ```yaml
   logrotate_remove: [apache2, apt, cron, fail2ban, rsyslog]
   ```

   For each name: a file a package ships is put back to the package's version if it was
   changed (by reinstalling the package with `--force-confmiss`) and left alone if not;
   a file no package ships is deleted. A file an entry has diverted
   (`replaces_package_file`) is left to that entry. Running it again changes nothing, so
   the list can stay until every host has had it.

   Don't list a name that an entry writes without diverting (a name no package ships):
   the two would delete and rewrite it on every run.

2. Write an entry for each log that still needs rotating: next to whatever creates the
   log, or in `logrotate_entries`. Use `replaces_package_file: true` only where you want
   different settings from the package's.

## Example Playbook

```yaml
- hosts: all
  become: true
  vars:
    logrotate_global_manage: true
    logrotate_global_dateext: true
    logrotate_entries:
      - name: monitor
        paths: [/var/log/monitor.log, /var/tmp/monitor-git.log]
        frequency: monthly
        rotate: 12
        copytruncate: true
  roles:
    - blacknell.ansible_roles.logrotate
```

## Testing

```bash
ansible-playbook -i tests/inventory tests/test.yml
```

## License

MIT

## Author Information

Paul Blacknell

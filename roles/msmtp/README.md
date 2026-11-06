# ansible-role-msmtp

Installs [msmtp](https://marlam.de/msmtp/) on Debian as the host's
`sendmail`, relaying mail through an SMTP server such as Fastmail or Gmail.
Programs that send mail through `/usr/sbin/sendmail` (cron, fail2ban's mail
actions, `mail`) then send it through that server, with no mail server on the
host.

The role only installs and configures msmtp. It doesn't depend on or notify
any other role. msmtp reads `/etc/msmtprc` each time it sends, so a config
change applies to the next message without restarting anything.

## Requirements

- Debian or a Debian-based distribution. Other platforms are skipped.
  Facts must be gathered (`gather_facts: true`, the default).
- An SMTP account. Use an app password where the provider offers one.
- The password is read from an environment variable on the controller
  (`SMTP_APP_PASSWORD` by default), e.g. with `op run`, unless you set
  `msmtp_password` yourself.

## Role Variables

The role stops with a message if a required variable is empty.

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `msmtp_host` | Yes | `""` | SMTP server to relay through |
| `msmtp_port` | No | `465` | SMTP port: `465` for TLS from the start, `587` with `msmtp_tls_starttls: true` |
| `msmtp_from` | Yes | `""` | Sender address for mail sent through msmtp |
| `msmtp_tls` | No | `true` | Encrypt the connection |
| `msmtp_tls_starttls` | No | `false` | Use STARTTLS (port 587) instead of TLS from the start |
| `msmtp_tls_trust_file` | No | `/etc/ssl/certs/ca-certificates.crt` | CA bundle used to check the server's certificate |
| `msmtp_auth` | No | `true` | Log in to the server |
| `msmtp_user` | With `msmtp_auth` | `""` | SMTP login user |
| `msmtp_password_env_var` | No | `SMTP_APP_PASSWORD` | Controller env var holding the password |
| `msmtp_password` | With `msmtp_auth` | value of that env var | The password, if you'd rather set it directly (e.g. from a vault) |
| `msmtp_account` | No | `smtp` | Account name in `/etc/msmtprc`, also the default account |
| `msmtp_logfile` | No | `/var/log/msmtp.log` | Log of sent mail. `""` for none |
| `msmtp_install_mta` | No | `true` | Install `msmtp-mta`, which provides `/usr/sbin/sendmail` |
| `msmtp_config_group` | No | `adm` | Group that can read `/etc/msmtprc`, and so send mail |
| `msmtp_config_mode` | No | `"0640"` | File mode of `/etc/msmtprc` |
| `msmtp_logrotate_enabled` | No | `true` | Write `/etc/logrotate.d/msmtp` for `msmtp_logfile` |
| `msmtp_logrotate_options` | No | monthly, keep 12, compressed | Body of that logrotate stanza |

## Behaviour

- `/etc/msmtprc` holds the password, so it's readable only by root and
  `msmtp_config_group`. A user outside both can't send mail. The file is
  left out of `--diff` output.
- Doesn't remove anything. Setting `msmtp_install_mta: false` leaves an
  installed `msmtp-mta` in place, and `msmtp_logrotate_enabled: false` leaves
  an existing `/etc/logrotate.d/msmtp`.
- **logrotate role:** its `msmtp` service writes the same
  `/etc/logrotate.d/msmtp`. Turn on one or the other, not both, or each run
  rewrites the other's file.

## Dependencies

None.

## Example Playbook

```yaml
- hosts: servers
  become: true
  roles:
    - role: blacknell.ansible_roles.msmtp
      tags: [msmtp]
```

with, in `group_vars/servers.yml`:

```yaml
msmtp_host: smtp.fastmail.com
msmtp_from: webmaster@example.com
msmtp_user: me@fastmail.com
msmtp_password_env_var: FASTMAIL_APP_PASSWORD
```

and run under `op run` (or with `FASTMAIL_APP_PASSWORD` exported).

## Checking it on a host

```bash
echo "Subject: test from $(hostname)" | sudo sendmail -v you@example.com
sudo tail /var/log/msmtp.log
```

## Testing

A minimal local test playbook is provided under `tests/`:

```bash
ansible-playbook -i tests/inventory tests/test.yml --check
```

## License

MIT

## Author Information

Paul Blacknell

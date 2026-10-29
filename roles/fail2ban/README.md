# ansible-role-fail2ban

Installs fail2ban on Debian with nftables bans and a set of jails for SSH,
Apache, Joomla, Home Assistant and Frigate. Bans can be reported to
AbuseIPDB and IPThreat, posted to Slack and MQTT, and sent as X-ARF abuse
emails.

Only the `sshd` jail is on by default. Every other jail and every reporting
action is switched on with variables, so the role can run against any host
and the per-site settings live in your `group_vars` and `host_vars`.

## Requirements

- Debian 11 (bullseye) or later, or a Debian derivative (Raspberry Pi OS,
  Ubuntu). Other platforms are skipped with a message. Facts must be gathered.
- The `ipthreat` action ships with fail2ban itself in recent releases, not
  with this role. It's only used when an IPThreat key is set, so check
  `/etc/fail2ban/action.d/ipthreat.conf` exists on your hosts before setting one.
- X-ARF reports need a working `/usr/sbin/sendmail`, e.g. msmtp. A mail
  role in the same play can notify `msmtp changed` to restart fail2ban.
- Enabled jails must find their log files: fail2ban won't start if an
  enabled jail's `logpath` matches nothing.

## Secrets

Secrets are read from environment variables on the Ansible controller, which
suits `op run -- ansible-playbook ...`. Each reporting action is only added
to the jails when its value is non-empty, so a host with no secrets gets plain
local bans.

| Secret | Env var (default) | Override the name with | Or set the value with |
|---|---|---|---|
| AbuseIPDB key | `ABUSEIPDB_KEY` | `fail2ban_abuseipdb_key_env_var` | `fail2ban_abuseipdb_apikey` |
| IPThreat key | `IPTHREAT_KEY` | `fail2ban_ipthreat_key_env_var` | `fail2ban_ipthreat_apikey` |
| Slack webhook (per-ban messages) | `FAIL2BAN_SLACK_WEBHOOK` | `fail2ban_slack_webhook_env_var` | `fail2ban_slack_webhook_url` |
| Slack bot token (repeat offenders, summary) | `FAIL2BAN_SLACK_BOT_TOKEN` | `fail2ban_slack_bot_token_env_var` | `fail2ban_slack_bot_token` |
| Slack channel for the bot | `FAIL2BAN_SLACK_CHANNEL` | `fail2ban_slack_channel_env_var` | `fail2ban_slack_channel` |
| MQTT password | `MQTT_PASSWORD` | `fail2ban_mqtt_password_env_var` | `fail2ban_mqtt_password` |

## Role Variables

| Variable | Default | Description |
|---|---|---|
| `fail2ban_ignoreip_base` | RFC1918 + loopback | Addresses never banned |
| `fail2ban_ignoreip_extra` | `[]` | Your own addresses/hostnames, added to the above |
| `fail2ban_bantime` | `7d` | Default ban time |
| `fail2ban_banaction` | `nftables` | Default ban action |
| `fail2ban_sshd_logpath` | `/var/log/auth.log` | sshd jail log |
| `fail2ban_apache_jails_enabled` | `false` | apache, apache-overflows, apache-badbots, apache-nohome, apache-404, apache-custom |
| `fail2ban_apache_access_logpath` | `/var/log/apache*/*access*.log` | Access logs for the Apache and Joomla jails |
| `fail2ban_apache_error_logpath` | `/var/log/apache*/*error*.log` | Error logs for the Apache jails |
| `fail2ban_enable_joomla_jails` | `false` | joomla-admin-bruteforce, -confirmed-exploit, -suspected-exploit, -recon-scan, -recon-scan-slow |
| `fail2ban_enable_repeat_offenders_jail` | `false` | recidive: 4-week all-ports ban for IPs banned twice in 28 days |
| `fail2ban_hass_jail_enabled` | `false` | Home Assistant failed logins |
| `fail2ban_hass_logpath` | `/var/log/homeassistant/home-assistant.log` | Home Assistant log |
| `fail2ban_frigate_jail_enabled` | `false` | Frigate behind an Apache reverse proxy |
| `fail2ban_frigate_logpath` | `/var/log/apache*/*access*.log` | Frigate proxy access log |
| `fail2ban_mqtt_enabled` | `false` | Publish bans to `fail2ban/<host>/<jail>/ban` (and `unban`); installs mosquitto-clients |
| `fail2ban_mqtt_host` / `_port` / `_user` | `homeassistant` / `1883` / `mqtt` | MQTT broker |
| `fail2ban_xarf_sender` | `""` | From/Bcc for X-ARF reports (joomla-confirmed-exploit, repeat-offenders). Empty: no reports |
| `fail2ban_summary_enabled` | `false` | Cron job posting the currently banned counts to Slack with the bot token |
| `fail2ban_summary_cron_hour` / `_minute` | `*/6` / `0` | Summary schedule |

All variables are also described in `meta/argument_specs.yml`, which Ansible
checks when the role runs.

## Dependencies

None.

## Example Playbook

```yaml
- hosts: webservers
  become: true
  roles:
    - role: blacknell.ansible_roles.fail2ban
```

with, in `group_vars/webservers.yml`:

```yaml
fail2ban_ignoreip_extra:
  - office.example.com
fail2ban_apache_jails_enabled: true
fail2ban_enable_repeat_offenders_jail: true
```

and per host, where Apache logs somewhere else:

```yaml
fail2ban_apache_access_logpath: /home/app/site/logs/*access*.log
fail2ban_apache_error_logpath: /home/app/site/logs/*error*.log
```

Run it with the secrets in the environment:

```bash
op run -- ansible-playbook -i inventory fail2ban.yml --limit myhost
```

## Checking it on a host

```bash
sudo fail2ban-client -t            # config test
sudo fail2ban-client status        # jails
sudo fail2ban-client status sshd   # bans in one jail
sudo nft list table inet f2b-table
```

## Testing

A minimal local test playbook is provided under `tests/`:

```bash
ansible-playbook -i tests/inventory tests/test.yml
```

## License

MIT

## Author Information

Paul Blacknell

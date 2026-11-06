# ansible-role-nftables_blocklist

Loads external IP reputation lists into nftables on Debian and keeps them
fresh with cron: [FireHOL](https://iplists.firehol.org/) levels 1-4 and
AbuseIPDB's blacklist. Each source gets its own nftables table, set and drop
counter, so you can see what each one is catching, and turn one off without
touching the others.

**Off by default.** Hosts get blocklists only when
`nftables_blocklist_enabled` is true, so the role can sit in a baseline
playbook with the switch set per host or group.

## Requirements

- Debian or a Debian-based distribution. Other platforms are skipped.
  Facts must be gathered (`gather_facts: true`, the default).
- nftables (`/usr/sbin/nft`). Hosts without it are skipped with a message.
  The role installs `curl`.
- IPv4 only. IPv6 entries in a list are skipped.
- An AbuseIPDB API key while the `abuseipdb` source is on (it is by default).
  It's read from an environment variable on the controller (`ABUSEIPDB_KEY`
  by default), e.g. with `op run`, unless you set `nftables_blocklist_abuseipdb_api_key`.
  The role stops with a message if it's empty.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `nftables_blocklist_enabled` | `false` | Install the refresh script and its cron jobs. `false` removes them |
| `nftables_blocklist_abuseipdb_key_env_var` | `ABUSEIPDB_KEY` | Controller env var holding the AbuseIPDB API key |
| `nftables_blocklist_abuseipdb_api_key` | value of that env var | The key, if you'd rather set it directly (e.g. from a vault) |
| `nftables_blocklist_abuseipdb_limit` | `500000` | Most entries to fetch from AbuseIPDB |
| `nftables_blocklist_abuseipdb_confidence_minimum` | `90` | Lowest abuse confidence score (0-100) to include |
| `nftables_blocklist_sources` | see below | The sources and their schedules |
| `nftables_blocklist_sources_override` | `{}` | Per-source changes, merged into `nftables_blocklist_sources` |
| `nftables_blocklist_script_path` | `/usr/local/bin/refresh-ip-blocklist.sh` | Where the refresh script goes |

Each source in `nftables_blocklist_sources` has `enabled`, `cron_name`, `minute`,
`hour` and `min_count`:

| Source | Schedule | `min_count` |
|--------|----------|-------------|
| `firehol1` | every 3 hours, on the hour | 1000 |
| `firehol2` | every 15 minutes | 100 |
| `firehol3` | every 15 minutes | 100 |
| `firehol4` | every 15 minutes | 100 |
| `abuseipdb` | daily at 02:00 | 100 |

All five are on. To change one, set only what differs, e.g.:

```yaml
nftables_blocklist_sources_override:
  firehol4:
    enabled: false
  abuseipdb:
    hour: "4"
```

Keep `cron_name` unchanged: it's how the cron job is found again, so a new
name adds a second job instead of replacing the first.

## Behaviour

- Turning a source off removes its cron job. Its table stays loaded until a
  reboot or `sudo nft delete table inet <source>_blocklist`.
- Setting `nftables_blocklist_enabled` back to `false` removes the script
  and every cron job. Loaded tables stay until a reboot.
- The script holds the AbuseIPDB key, so it's readable only by root and is
  left out of `--diff` output.
- The tables live in memory, so a reboot removes them. Each source comes back
  at its next scheduled run, which for `abuseipdb` can be up to a day.
- Tables run after fail2ban's `f2b-table` (see the hook priorities below), and
  are separate from it.

## Dependencies

None.

## Example Playbook

```yaml
- hosts: servers
  become: true
  roles:
    - role: blacknell.ansible_roles.nftables_blocklist
      tags: [nftables_blocklist]
```

with, in `group_vars/servers.yml`:

```yaml
nftables_blocklist_enabled: true
```

and run under `op run` (or with `ABUSEIPDB_KEY` exported).

Run one source by hand on a host:

```bash
sudo /usr/local/bin/refresh-ip-blocklist.sh --source firehol1 --dry-run
sudo /usr/local/bin/refresh-ip-blocklist.sh --source firehol1
```

## Testing

A minimal local test playbook is provided under `tests/`:

```bash
ansible-playbook -i tests/inventory tests/test.yml --check
```

## How the refresh script works

### Sources

One script, selected per-run via `--source`:

| Source      | Content                        | Auth required |
|-------------|---------------------------------|----------------|
| `firehol1`  | FireHOL Level 1 (max protection, min false positives) | no |
| `firehol2`  | FireHOL Level 2 | no |
| `firehol3`  | FireHOL Level 3 | no |
| `firehol4`  | FireHOL Level 4 — FireHOL's own wiki notes a higher false-positive rate than 1–3 | no |
| `abuseipdb` | AbuseIPDB `/blacklist` endpoint | yes — `nftables_blocklist_abuseipdb_api_key`, templated into the script at deploy time |

**Level 4 decision:** no special-casing (monitor-only mode, separate threshold, etc.). If it's invoked, it drops traffic like every other source. Whether to run it is decided by its cron job (`nftables_blocklist_sources_override: {firehol4: {enabled: false}}` turns it off), not inside the script.

### Isolation

Every source gets its own nftables table, set, chain, and drop rule (`firehol1_blocklist`, `firehol2_blocklist`, `firehol3_blocklist`, `firehol4_blocklist`, `abuseipdb_blocklist`). Nothing is merged into a shared set. This keeps each source's drop counter (`nft list chain`) individually meaningful, and means one source can be disabled, inspected, or torn down without touching the others. All tables are separate from Fail2Ban's own `inet f2b-table`.

Each table's chain also gets its own `hook input` priority: `firehol1` at `0`, `firehol2` at `1`, `firehol3` at `2`, `firehol4` at `3`, `abuseipdb` at `4` -- staggered so they run in that order, all *after* Fail2Ban's `f2b-table` (priority `-1` by default). Fail2Ban runs first, then firehol1 → firehol2 → firehol3 → firehol4 → abuseipdb last. Verify actual live values with:

```
sudo nft list ruleset | awk '/^table /{t=$0} /hook input/{gsub(/^[ \t]+/,"",$0); print t" -> "$0}'
```

This ordering only affects which table's counter gets credited when an IP appears on more than one list -- each chain drops matched traffic independently of what ran before it, so a bad IP is dropped regardless of tie-breaking. There is no supported way to change an already-bootstrapped table's chain priority in place; applying a new value to an existing table requires `nft delete table inet <table>` (which also resets that table's counter) before the next run re-bootstraps it.

### Update mechanism

Table, chain, and rule are bootstrapped **once** per source, the first time the script runs for it (checked via `nft list table inet <table>`). The tables live in memory only, so a reboot removes them; a run that finds its table missing skips the ETag and hash checks below and reloads, so the next scheduled run after a reboot puts the list back. Every later invocation only does `flush set` + `add element` inside a single atomic `nft -f` transaction — the chain and its drop rule are never deleted or recreated.

This is a deliberate change from the original script's full delete-and-rebuild-every-run approach: nftables has no supported way to update an existing table's properties in place, so the only way to change something like a stored comment is to destroy and recreate the table — which also resets its rule's packet/byte counters. Since persistent counters were a stated requirement, the comment had to move elsewhere (see below) so the table could stop being rebuilt every run.

Large sets are loaded in chunks of 5,000 elements per `add element` statement (still inside the one atomic transaction) rather than a single inline element list, since AbuseIPDB and the larger FireHOL levels can be big enough to hit netlink message-size limits otherwise.

### Freshness handling

The source's own "generated at" date is written to syslog/journal via `logger`, not stored as an nftables table comment. Every source logs under one shared tag, `refresh-blocklist` -- not `<source>-blocklist` -- with each line prefixed `[$SOURCE]` for attribution. `journalctl -t refresh-blocklist` gives a full history across every source in one place; add `| grep '\[firehol1\]'` (etc.) to narrow to a single source. This is strictly more useful than a single value that gets overwritten on each run anyway.

Two extraction methods, depending on source:
- **FireHOL** — parsed from the `# This File Date` line inside the downloaded list body.
- **AbuseIPDB** — read from the `X-Generated-At` HTTP response header.

### Change detection

- **FireHOL sources:** conditional GET via `If-None-Match` using the previous run's stored ETag (GitHub's raw-content CDN supports this reliably). Independently of that, the normalized body (comments and blank lines stripped) is SHA-256 hashed and compared against the previous run's stored hash — the reload is skipped whenever the hash matches, regardless of whether the ETag round-trip fired a 304 or a fresh 200 with identical content. Both are best-effort speed-ups, not correctness checks: a 304/hash-match skips the nft reload and logs "unchanged," it never skips the validation step below.
- **AbuseIPDB:** no conditional-request logic at all — always fetched, always reloaded. It's refreshed at most once per day by hand/timer, so there's nothing worth saving by checking first, and AbuseIPDB's API docs don't document ETag/conditional-request support (only `X-RateLimit-*` and `X-Generated-At`), so it wasn't worth building against an unconfirmed behavior.

### Inspecting counters

Each table's drop rule references a **named** counter object (`drops`), rather than nftables' default inline/anonymous counter, specifically so it can be queried on its own:

```
nft list counter inet firehol1_blocklist drops
```

This prints just the counter — packets, bytes, and its comment (the source name) — with no set-element dump or other chain noise mixed in. Swap the table name for any other source's table (`abuseipdb_blocklist`, `firehol2_blocklist`, etc.).

### Dry run

`--dry-run` evaluates a source exactly as a real run would — same conditional request (if applicable), same content hash comparison, same `MIN_COUNT` validation — but never touches nftables and never writes the ETag/hash state files. Because it writes nothing, running it has zero effect on what the next real run sees: you can dry-run as often as you like without masking a genuine change from the scheduled job.

Output goes to stdout (not the journal, since this is for interactive/manual inspection) and reports: whether the source has changed since the last real run, the freshness date it found, entry count, whether the target table already exists or would need bootstrapping, and a truncated before/after hash for changed content.

### Forcing a refresh

`--skip-modified-checks` disables the ETag/hash gating entirely for the run — no `If-None-Match` sent, no hash comparison, always fetch and always reload. It reuses the same code path already built for AbuseIPDB (`USE_CONDITIONAL=no`), so for AbuseIPDB itself the flag is a no-op. Intended for a manual forced refresh — e.g. right after changing a source's `MIN_COUNT` or other config, where you want current content reapplied even though upstream may not have changed since the last run. Combines with `--dry-run` if you just want to preview what a forced run would do.

### Validation / safety (carried over from the original script)

- **Minimum entry-count floor** per source (`min_count` in `nftables_blocklist_sources`) — abort rather than load a suspiciously short list (truncated fetch, upstream outage). Defaults are starting guesses (1,000 for FireHOL L1 matching its known ~3,800-entry size with headroom; 100 for the others) and can be tuned per host.
- **Loopback exception** (`iif "lo" accept` before the drop rule) — FireHOL's lists correctly include bogon ranges like `127.0.0.0/8` as sources that should never arrive from the network, but this chain matches purely on source address ahead of most other rules; without the exception, genuine local loopback traffic would be dropped too.
- **Atomic apply** — every `nft` mutation (bootstrap or refresh) is a single `nft -f` transaction, so there's never a window where the drop rule is transiently absent or the set is transiently empty.

### Explicitly out of scope for this version

- IPv6 (matches the original script's scope; not requested for this iteration)
- Multi-source aggregation into a single set (deliberately rejected — isolation was a stated requirement)
- Auto-whitelisting of the server's own IPs (not requested; revisit if a source's list ever risks catching this host's own address)

### Jinja templating gotcha

The script is deployed from `templates/refresh-ip-blocklist.sh.j2`, templated by Ansible for the AbuseIPDB key and parameters and each source's `min_count`. One collision to know about: Jinja's comment delimiter is `{#`, and bash's array-length syntax `${#chunk[@]}` (in the chunking loop) contains that exact sequence — left unescaped, Jinja reads it as an unterminated comment and fails to render the whole template. The chunking loop's `while` line is wrapped in `{% raw %}...{% endraw %}` to prevent this. If that loop is ever rewritten, keep the raw-block wrapper (or avoid `${#...}` bash syntax entirely) — this is easy to reintroduce by accident.

## Checking it on a host
### Checking filter drop counters

```shell
watch -n 30 'sudo nft list counters inet'
```

### Logging commands

All sources log under the single tag `refresh-blocklist`, with each line prefixed `[$SOURCE]` (e.g. `[firehol1]`, `[abuseipdb]`) for attribution.

#### Follow live

```shell
journalctl -t refresh-blocklist -f
```

#### Last 6 hours only

```shell
journalctl -t refresh-blocklist --since "6 hours ago"
```

#### Show all log entries

```shell
journalctl -t refresh-blocklist
```

#### Filter to a single source

```shell
journalctl -t refresh-blocklist | grep '\[firehol1\]'
```

Swap `firehol1` for `firehol2`, `firehol3`, `firehol4`, or `abuseipdb` as needed.

## License

MIT

## Author Information

Paul Blacknell

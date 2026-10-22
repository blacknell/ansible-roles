# ansible-role-nginx_proxy

An [nginx](https://nginx.org/) reverse proxy installed on the host from the distro
package, in front of services on the same host, for example containers publishing on
`127.0.0.1`. Certificates come from [certbot](https://certbot.eff.org/), typically
[geerlingguy.certbot](https://github.com/geerlingguy/ansible-role-certbot); this role
writes the nginx side and hands certbot its list of certificates.

- **One vhost per entry in `nginx_proxy_sites`**, in `/etc/nginx/sites-available/<name>.conf`
  and enabled in `sites-enabled/`. Its HTTPS server is only written once the site's
  certificate exists in `/etc/letsencrypt/live/<name>/`. Until then the site is served on
  port 80 for ACME challenges only, so a site without a certificate can never stop nginx
  from starting for the others.
- **A catch-all site** answers ACME challenges for every name and refuses TLS handshakes for
  names it has no certificate for. It replaces the distro's default site.
- **`nginx_proxy_certbot_certs`** is set from the same site list, ready for
  geerlingguy.certbot's `certbot_certs`, so each site is defined once.
- **A certbot deploy hook** reloads nginx after a certificate renews (nginx keeps the old
  one in memory until then).
- **Renewal configs** of managed certificates are pointed at `nginx_proxy_acme_root`, so a
  certificate copied from another host renews here, including one first issued with
  another plugin such as apache (the webroot settings are added).
- Every change is checked with `nginx -t` before nginx is reloaded.

## Requirements

- Debian or Ubuntu, `openssl`
- sudo; the tasks escalate as needed
- Ansible core >= 2.15
- DNS for each domain pointing at this host before certbot requests its certificate

## Role Variables

### Sites

`nginx_proxy_sites` is a list; each entry is one vhost and one certificate.

| Key | Default | Description |
|---|---|---|
| `name` | required | Vhost filename and certificate name |
| `upstream` | | `scheme://host:port`, with no path or trailing slash, e.g. `http://127.0.0.1:8080`. Set this or `redirect_to` |
| `redirect_to` | | Instead of proxying, `301` every request to this `scheme://host`, keeping the path and query, e.g. `https://www.example.com` for a bare domain. It still gets its own certificate, so HTTPS requests to it redirect too |
| `domains` | `[name]` | Names on the certificate and the vhost |
| `state` | `present` | `absent` removes the vhost (the certificate is kept) |
| `issue` | `true` | Include the site in `nginx_proxy_certbot_certs`. `false` until DNS points here, or for a certificate you copy in yourself |
| `client_max_body_size` | `1m` | For the HTTPS server |
| `proxy_buffering` | `true` | For the HTTPS server; `false` for streaming apps such as Jenkins |
| `extra_server_config` | `""` | Raw nginx lines for the HTTPS server block |
| `extra_location_config` | `""` | Raw nginx lines for its `location /` block |

Every HTTPS site gets websocket upgrade support, HTTP/2, the `X-Forwarded-*` headers and
the Mozilla "intermediate" TLS settings.

### Other

| Variable | Default | Description |
|---|---|---|
| `nginx_proxy_package_state` | `present` | `present` or `latest` |
| `nginx_proxy_acme_root` | `/var/www/letsencrypt` | ACME challenge folder served for every name; use the same path as certbot's webroot (`certbot_webroot`) |
| `nginx_proxy_letsencrypt_dir` | `/etc/letsencrypt` | certbot's config folder |
| `nginx_proxy_ipv6` | whether the host has an IPv6 address | Also listen on IPv6 |
| `nginx_proxy_remove_default_site` | `true` | Remove the distro's `sites-enabled/default` |
| `nginx_proxy_renewal_hook` | `true` | Install `<letsencrypt_dir>/renewal-hooks/deploy/nginx-proxy-reload` |
| `nginx_proxy_fix_renewal_configs` | `true` | Point each managed certificate's renewal config at `nginx_proxy_acme_root` (webroot authenticator, no installer) |
| `nginx_proxy_expiry_warn_days` | `14` | Warn about certificates with fewer days left than this |

### Set by the role

| Fact | Description |
|---|---|
| `nginx_proxy_certbot_certs` | `[{name, domains, webroot}]` for each present site with `issue: true`, in geerlingguy.certbot's `certbot_certs` format |

## Entry Points

| Entry point | What it does |
|---|---|
| `main` | Installs nginx, the shared config, catch-all site and renewal hook, writes the vhosts, tests and reloads nginx, and reports each site |
| `vhosts` | Writes the vhosts again, tests and reloads nginx, and reports. Installs nothing. Run it after certbot so newly certified sites switch to HTTPS |

Files written under `/etc/nginx`: `conf.d/nginx-proxy.conf`, `snippets/nginx-proxy-ssl.conf`,
`snippets/nginx-proxy-headers.conf`, `sites-available/00-default.conf` and one
`sites-available/<name>.conf` per site. Logs go to `/var/log/nginx/<name>.access.log` and
`<name>.error.log`, rotated by the distro's nginx logrotate config.

## Dependencies

None. geerlingguy.certbot is used alongside it, not as a dependency.

## Example Playbook

```yaml
- hosts: web_proxies
  become: true # geerlingguy.certbot's tasks don't escalate themselves
  vars:
    nginx_proxy_sites:
      - name: ci.example.com
        upstream: http://127.0.0.1:8080
        client_max_body_size: 100m
        proxy_buffering: false

    certbot_certs: "{{ nginx_proxy_certbot_certs }}"
    certbot_create_if_missing: true
    certbot_create_method: webroot
    certbot_webroot: /var/www/letsencrypt
    certbot_admin_email: webmaster@example.com
    certbot_expand: true
    certbot_auto_renew: false # Debian's certbot.timer renews; the deploy hook reloads nginx
  roles:
    - blacknell.ansible_roles.nginx_proxy
    - geerlingguy.certbot
  tasks:
    - name: Switch newly certified sites to HTTPS
      ansible.builtin.include_role:
        name: blacknell.ansible_roles.nginx_proxy
        tasks_from: vhosts
```

The report at the end shows one line per site, for example:

```
ci.example.com: HTTPS -> http://127.0.0.1:8080, certificate valid 72 days (until Jan  2 08:13:32 2027 GMT)
www.example.com: HTTP only: no certificate yet (issue: false)
```

## Copying in an existing certificate

To move a site from another host without a gap in HTTPS, copy its certificate before the
first run. Use `tar`, because `live/` holds symlinks into `archive/`, and include
`accounts/`, because the renewal config names the ACME account:

```bash
ssh old-host 'sudo tar -C /etc/letsencrypt -czf - accounts live/example.com archive/example.com renewal/example.com.conf' \
  | ssh new-host 'sudo mkdir -p /etc/letsencrypt && sudo tar -C /etc/letsencrypt -xzf -'
```

The vhost then goes straight to HTTPS, certbot sees the certificate exists and leaves it,
and its renewal config is pointed at `nginx_proxy_acme_root`. Check renewal with:

```bash
sudo certbot renew --dry-run --cert-name example.com --agree-tos --email you@example.com
```

A dry run talks to Let's Encrypt's staging server, which needs its own account; the
`--agree-tos --email` only registers that one. Real renewals use the copied production
account, which is why `accounts/` has to come across too.

## Testing

```bash
ansible-playbook -i tests/inventory tests/test.yml --syntax-check
```

## License

MIT

## Author Information

Paul Blacknell

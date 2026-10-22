# ansible-role-swap

Adds a swap file on Debian hosts that ask for one, adds it to `/etc/fstab` and
sets `vm.swappiness`. With no swap, a host that runs out of memory can freeze
until the kernel's OOM killer kills something. With swap, it slows down instead.

**Off by default.** Hosts get a swap file only when `swap_file_size_mb` is
above 0, so the role can sit in a baseline playbook that runs against every
host, with the size set per host in `host_vars`.

## Requirements

- Debian or a Debian-based distribution. Other platforms are skipped.
  Facts must be gathered (`gather_facts: true`, the default).
- The `ansible.posix` collection (`mount`, `sysctl`).
- `swap_file_path` on ext4 or xfs. Swap files made with `fallocate` don't work
  on btrfs or zfs.
- Hosts with a package listed in `swap_skip_if_installed` (`vars/main.yml`) are
  skipped with a message. Currently that's `dphys-swapfile`, Raspberry Pi OS's
  swap manager: size swap on those hosts in `/etc/dphys-swapfile`.
- Not for LXC/containers, which can't turn swap on.

## Role Variables

| Variable            | Required | Default                      | Description |
|---------------------|----------|------------------------------|-------------|
| `swap_file_size_mb` | No       | `0`                          | Size of the swap file in MB. `0` leaves swap alone |
| `swap_file_path`    | No       | `/swapfile`                  | Where the swap file goes |
| `swap_swappiness`   | No       | `10`                         | `vm.swappiness`. Low means swap is used only when memory is really short |
| `swap_sysctl_file`  | No       | `/etc/sysctl.d/90-swap.conf` | Where the swappiness setting is written |

## Behaviour

- Creates the file with `fallocate`, restricts it to root, formats it with
  `mkswap`, adds it to `/etc/fstab` and turns it on. Runs again change nothing.
- **Doesn't resize.** Turning a swap file off pushes everything in it back into
  memory, exactly when memory is short, so an existing file of a different size
  is reported and left alone. To resize, on the host run
  `sudo swapoff /swapfile && sudo rm /swapfile`, then run the role again.
- Setting `swap_file_size_mb` back to `0` doesn't remove an existing swap file.
- Works in `--check` mode on a host that has no swap file yet.

## Dependencies

None.

## Example Playbook

```yaml
- hosts: all
  become: true
  roles:
    - role: blacknell.ansible_roles.swap
      tags: [swap]
```

with, in `host_vars/<host>.yml`:

```yaml
swap_file_size_mb: 2048
```

Run just this role on one host with `--limit <host> --tags swap`.

## Checking it on a host

```bash
sudo swapon --show       # active swap
free -h                  # memory and swap use
sysctl vm.swappiness
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

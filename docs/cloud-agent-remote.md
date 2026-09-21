# Cursor cloud agent: `herdr --remote` with latency

## Why this repo

Cursor cloud agents run on a Linux VM with a desktop. We want to verify that
`herdr --remote` stays usable when the path to the remote host looks like a
high-RTT WAN (≈200 ms), without depending on a real Asia↔US hop.

## Prerequisites on the cloud agent VM

Verified on Cursor cloud-agent Ubuntu 24.04: `tc`/`ip` are **not** preinstalled,
`herdr` is not on `PATH`, and `~/.local/bin` is not on the default `PATH`.
Passwordless `sudo` is available. `openssh-client` is present. The image does
**not** include SSH keys or a remote host config (e.g. deb1). Do not invent
credentials.

1. This repo checked out. `scripts/netem.sh` is executable in git (`100755`).
2. `iproute2` (`tc` and `ip`):

   ```bash
   sudo apt-get update
   sudo apt-get install -y iproute2
   command -v tc && command -v ip
   ```

3. Official Linux `herdr` on `PATH` (stable installer / GitHub release assets
   from [herdr.dev](https://herdr.dev/docs/install/) — do not use private
   binaries):

   ```bash
   curl -fsSL https://herdr.dev/install.sh | sh
   export PATH="$HOME/.local/bin:$PATH"
   herdr --version
   ```

   The installer writes `~/.local/bin/herdr`. Add that directory to `PATH` in
   the current shell (and in `~/.bashrc` if you need it across panes).

4. SSH reachability to a remote that already runs a herdr server (e.g. deb1),
   **or** a second local container/VM acting as the remote. Confirm with
   `ssh <host>` before `herdr --remote`. Until a key + host are provided,
   stop after herdr install + netem dry-run.

## Dry-run netem (no remote needed)

`status` does not need sudo:

```bash
./scripts/netem.sh status
```

`apply` / `clear` need root. If you apply on this VM, use `--dst` (do not shape
all egress) and a short `--ttl`, then clear — do not leave netem enabled:

```bash
sudo ./scripts/netem.sh apply --dst 203.0.113.10/32 --delay 200ms --jitter 20ms --ttl 30
sudo ./scripts/netem.sh clear
./scripts/netem.sh status
```

`apply` defaults to a 600s auto-clear (`--ttl 0` to disable).

## Apply latency (real remote)

Prefer destination-scoped shaping so control paths stay usable:

```bash
REMOTE_IP=$(getent ahostsv4 your.remote.host | awk '{print $1; exit}')
sudo ./scripts/netem.sh apply --dst "${REMOTE_IP}/32" --delay 200ms --jitter 20ms
```

Mild loss scenario:

```bash
sudo ./scripts/netem.sh apply --dst "${REMOTE_IP}/32" \
  --delay 200ms --jitter 20ms --loss 1%
```

See [matrix.md](matrix.md) for the full IV-0002 set (jitter/loss/reorder/rate).

## Attach

From a **desktop** terminal emulator (`DISPLAY` is typically `:1` on the cloud
agent), after `ssh <host>` works:

```bash
HERDR_REMOTE_TIMING=1 herdr --remote user@your.remote.host
# or an SSH config Host:
# HERDR_REMOTE_TIMING=1 herdr --remote workbox
# optional, if build supports it:
# HERDR_ECHO_TIMING=1 herdr --remote user@your.remote.host
```

Use a real terminal emulator (not only a headless shell) when you care about
TUI feel (pi, htop, editors). Official remote-attach notes:
https://herdr.dev/docs/persistence-remote/

## What to record

See [matrix.md](matrix.md). Minimum:

- attach phases from `HERDR_REMOTE_TIMING=1`
- subjective typing feel at 200 ms
- whether predictive echo (if present on the client under test) hides RTT

## Cleanup

```bash
sudo ./scripts/netem.sh clear
./scripts/netem.sh status
```

## Next step after this dry-run

Provide an SSH identity and host (for example deb1: `Host` alias, hostname,
user, and a key the cloud agent may use). Then:

1. `ssh <host>` (accept host key if needed).
2. Destination-scoped netem at `delay 200ms 20ms` toward that host’s IP.
3. `HERDR_REMOTE_TIMING=1 herdr --remote <host>` from the desktop terminal.
4. `sudo ./scripts/netem.sh clear`.

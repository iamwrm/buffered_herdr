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

`apply` / `clear` need root. If you apply, use `--dst` (do not shape all egress)
and a short `--ttl`, then clear — do not leave netem enabled:

```bash
sudo ./scripts/netem.sh apply --dst 203.0.113.10/32 --delay 200ms --jitter 20ms --ttl 30
sudo ./scripts/netem.sh clear
./scripts/netem.sh status
```

`apply` defaults to a 600s auto-clear (`--ttl 0` to disable).

### Kernel limitation: no `sch_netem` on this image

On Cursor cloud-agent kernel `6.12.94+` (Sept 2026 check): `iproute2` installs and
`./scripts/netem.sh status` works, but `apply` fails with
`Specified qdisc kind is unknown` for `netem` and `prio`. The pod has no
`/lib/modules` and no `modprobe`; only basic FIFO qdiscs (`pfifo` / `bfifo`)
are accepted. There is nothing to load — simulated 200 ms RTT **cannot** be
applied on this VM until the environment kernel includes `CONFIG_NET_SCH_NETEM`
(and `CONFIG_NET_SCH_PRIO` for `--dst` filters).

Until that exists, do the 200 ms attach on a hop whose kernel has netem
(self-hosted worker, a Linux VM you control, or `tc` on the remote/middlebox).

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

Two things are still required for a real `--remote` attach under 200 ms:

1. **SSH to a herdr server** (e.g. deb1): `Host` alias, hostname, user, and a
   key this VM may use. None of that is on the image; do not invent credentials.
   Confirm with `ssh <host>` before `herdr --remote`.
2. **A netem-capable kernel** on the shaped hop. This cloud-agent kernel cannot
   install `netem`. Use a self-hosted worker / Linux VM with netem, or run
   `./scripts/netem.sh apply --dst …` on a host that can, then attach from the
   desktop (`DISPLAY=:1`) with:

   ```bash
   HERDR_REMOTE_TIMING=1 herdr --remote <host>
   ```

   Clear qdiscs when done. `HERDR_REMOTE_TIMING` / `HERDR_ECHO_TIMING` come from
   the IV-0002 harness; official `herdr` 0.9.1 still accepts `--remote`.

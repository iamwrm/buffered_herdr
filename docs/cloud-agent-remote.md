# Cursor cloud agent: `herdr --remote` with latency

## Why this repo

Cursor cloud agents run on a Linux VM with a desktop. We want to verify that
`herdr --remote` stays usable when the path to the remote host looks like a
high-RTT WAN (≈200 ms), without depending on a real Asia↔US hop.

## Prerequisites on the cloud agent VM

1. This repo checked out.
2. `iproute2` (`tc`) available (usually present).
3. Official Linux `herdr` on `PATH` (install from https://herdr.dev / release assets).
4. SSH reachability to a remote that already runs a herdr server (e.g. deb1),
   or a second local container/VM acting as the remote.

## Apply latency

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

`apply` defaults to a 600s auto-clear (`--ttl 0` to disable).

## Attach

```bash
HERDR_REMOTE_TIMING=1 herdr --remote user@your.remote.host
# optional, if build supports it:
# HERDR_ECHO_TIMING=1 herdr --remote user@your.remote.host
```

On the cloud agent **desktop**, run the attach from a real terminal emulator
(not only a headless shell) when you care about TUI feel (pi, htop, editors).

## What to record

See [matrix.md](matrix.md). Minimum:

- attach phases from `HERDR_REMOTE_TIMING=1`
- subjective typing feel at 200 ms
- whether predictive echo (if present on the client under test) hides RTT

## Cleanup

```bash
sudo ./scripts/netem.sh clear
```

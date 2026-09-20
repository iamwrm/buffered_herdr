# buffered_herdr

Dev harness for exercising [`herdr`](https://github.com/herdrdev/herdr) **`--remote`** on a **Cursor cloud agent** Linux desktop, with **simulated latency** (tc/netem).

Tracks Linear [REN-103](https://linear.app/ren15/issue/REN-103/buffered-herdr).

Related prior art: [iamwrm/herdr-windows-remote](https://github.com/iamwrm/herdr-windows-remote) IV-0002 (deb1 netem matrix + predictive echo). This repo is the **cloud-agent / Linux desktop** side of that story, not the Windows client patch stack.

## Goals

1. Public, minimal repo a Cursor cloud agent can clone and run on its VM desktop.
2. Scripts to shape egress (and optionally ingress) with netem so `--remote` sees Asia↔US-like RTT.
3. A short runbook to attach `herdr --remote` under that latency and collect timing (`HERDR_REMOTE_TIMING`, `HERDR_ECHO_TIMING` when available).

## Quick start (cloud agent VM)

```bash
# 1) Install herdr (official Linux binary) if missing — see docs/cloud-agent-remote.md
# 2) Apply simulated latency toward a peer IP (or whole default route — careful)
sudo ./scripts/netem.sh apply --delay 200ms --jitter 20ms
# 3) In another pane / after SSH target is ready:
HERDR_REMOTE_TIMING=1 herdr --remote user@host
# 4) Cleanup
sudo ./scripts/netem.sh clear
```

Default netem matrix (from IV-0002):

| Scenario | netem |
|---|---|
| Asia↔US baseline | `delay 200ms 20ms` |
| + mild loss | `delay 200ms 20ms loss 1%` |
| bad wifi + WAN | `delay 200ms 50ms loss 3% 25% reorder 1%` |

## Layout

| Path | Role |
|---|---|
| `scripts/netem.sh` | apply / clear / status for tc netem |
| `docs/cloud-agent-remote.md` | Cursor cloud agent desktop `--remote` runbook |
| `docs/matrix.md` | Latency scenarios and what to record |

## Safety

Shaping the wrong interface or destination can lock you out of SSH. Prefer matching a **destination IP** (`--dst`), and use the built-in auto-clear timer (`--ttl`) on first runs.

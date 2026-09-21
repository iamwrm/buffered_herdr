# buffered_herdr

Dev harness for exercising [`herdr`](https://github.com/herdrdev/herdr) **`--remote`** on a **Cursor cloud agent** Linux desktop, with **simulated latency** (tc/netem).

Tracks Linear [REN-103](https://linear.app/ren15/issue/REN-103/buffered-herdr).

Related prior art: [iamwrm/herdr-windows-remote](https://github.com/iamwrm/herdr-windows-remote) IV-0002 (deb1 netem matrix + predictive echo). This repo is the **cloud-agent / Linux desktop** side of that story, not the Windows client patch stack.

## Goals

1. Public, minimal repo a Cursor cloud agent can clone and run on its VM desktop.
2. Scripts to shape egress (and optionally ingress) with netem so `--remote` sees Asia↔US-like RTT.
3. A short runbook to attach `herdr --remote` under that latency and collect timing (`HERDR_REMOTE_TIMING`, `HERDR_ECHO_TIMING` when available).

## Quick start (cloud agent VM)

`tc`/`ip` and `herdr` are **not** on the stock Cursor cloud-agent image. See
[docs/cloud-agent-remote.md](docs/cloud-agent-remote.md) for the full runbook.

```bash
sudo apt-get update && sudo apt-get install -y iproute2
curl -fsSL https://herdr.dev/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
herdr --version
./scripts/netem.sh status   # no sudo; apply needs sch_netem (see docs)

# After SSH to a real remote exists (do not invent keys) *and* the hop
# can install netem (this cloud-agent kernel currently cannot):
REMOTE_IP=$(getent ahostsv4 your.remote.host | awk '{print $1; exit}')
sudo ./scripts/netem.sh apply --dst "${REMOTE_IP}/32" --delay 200ms --jitter 20ms
HERDR_REMOTE_TIMING=1 herdr --remote user@host
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

Cursor cloud-agent kernels may lack `sch_netem` (`qdisc kind is unknown`). `status` still works; delay shaping needs a kernel with netem — see [docs/cloud-agent-remote.md](docs/cloud-agent-remote.md).

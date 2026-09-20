# Latency test matrix

Copied from [herdr-windows-remote IV-0002](https://github.com/iamwrm/herdr-windows-remote/blob/master/docs/IV-0002-latency-improvements.md) for cloud-agent runs.

| Scenario | `netem.sh` args |
|---|---|
| Asia↔US baseline | `--delay 200ms --jitter 20ms` |
| + mild loss | `--delay 200ms --jitter 20ms --loss 1%` |
| bad wifi + WAN | `--delay 200ms --jitter 50ms --loss '3% 25%' --reorder 1%` |
| thin pipe | above + `--rate 5mbit` |

Per scenario, record:

1. `HERDR_REMOTE_TIMING=1` attach phase timings (cold vs warm if cache applies).
2. Echo feel: slow typing (~2 key/s) vs fast (~8 key/s).
3. Subjective TUI: pi / editor / `htop`.
4. Large `cat` / scroll (frame-skip behavior).

Log results under `notes/` (create as needed) or on REN-103 comments.

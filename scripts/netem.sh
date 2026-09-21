#!/usr/bin/env bash
# tc/netem helpers for buffered_herdr (Cursor cloud agent / Linux).
# Pattern adapted from iamwrm/herdr-windows-remote docs/IV-0002.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sudo ./scripts/netem.sh apply [options]
  sudo ./scripts/netem.sh clear [options]
  ./scripts/netem.sh status [options]

Options:
  --dev IFACE       Network device (default: first default-route iface)
  --dst CIDR        Only shape traffic to this destination (e.g. 1.2.3.4/32)
  --delay SPEC      netem delay, e.g. 200ms (default: 200ms)
  --jitter SPEC     netem jitter, e.g. 20ms (default: 20ms)
  --loss SPEC       e.g. '1%' or '3% 25%' (optional)
  --reorder SPEC    e.g. '1%' (optional)
  --rate SPEC       e.g. 5mbit (optional)
  --ttl SECONDS     Auto-clear after N seconds (default: 600 when apply; 0=off)
  -h, --help

Examples:
  sudo ./scripts/netem.sh apply --dst 203.0.113.10/32 --delay 200ms --jitter 20ms
  sudo ./scripts/netem.sh apply --delay 200ms --jitter 50ms --loss '3% 25%' --reorder 1%
  sudo ./scripts/netem.sh clear
EOF
}

default_dev() {
  ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}'
}

DEV=""
DST=""
DELAY="200ms"
JITTER="20ms"
LOSS=""
REORDER=""
RATE=""
TTL=""
CMD=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    apply|clear|status) CMD="$1"; shift ;;
    --dev) DEV="$2"; shift 2 ;;
    --dst) DST="$2"; shift 2 ;;
    --delay) DELAY="$2"; shift 2 ;;
    --jitter) JITTER="$2"; shift 2 ;;
    --loss) LOSS="$2"; shift 2 ;;
    --reorder) REORDER="$2"; shift 2 ;;
    --rate) RATE="$2"; shift 2 ;;
    --ttl) TTL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$CMD" ]]; then
  usage
  exit 2
fi

if [[ -z "$DEV" ]]; then
  DEV="$(default_dev)"
fi
if [[ -z "$DEV" ]]; then
  echo "could not detect default iface; pass --dev" >&2
  exit 1
fi

need_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "need root (sudo) for $CMD" >&2
    exit 1
  fi
}

clear_qdisc() {
  tc qdisc del dev "$DEV" root 2>/dev/null || true
}

status_qdisc() {
  echo "# device: $DEV"
  tc qdisc show dev "$DEV"
  tc filter show dev "$DEV" 2>/dev/null || true
}

apply_qdisc() {
  need_root
  clear_qdisc

  local netem_args=(delay "$DELAY")
  if [[ -n "$JITTER" ]]; then
    netem_args+=("$JITTER")
  fi
  if [[ -n "$LOSS" ]]; then
    # shellcheck disable=SC2206
    local loss_parts=($LOSS)
    netem_args+=(loss "${loss_parts[@]}")
  fi
  if [[ -n "$REORDER" ]]; then
    netem_args+=(reorder "$REORDER")
  fi

  if [[ -n "$DST" ]]; then
    tc qdisc add dev "$DEV" root handle 1: prio
    tc qdisc add dev "$DEV" parent 1:3 handle 30: netem "${netem_args[@]}"
    if [[ -n "$RATE" ]]; then
      tc qdisc add dev "$DEV" parent 30:1 handle 40: tbf rate "$RATE" burst 32kbit latency 400ms
    fi
    tc filter add dev "$DEV" parent 1: protocol ip u32 \
      match ip dst "$DST" flowid 1:3
  else
    echo "WARNING: no --dst; shaping ALL egress on $DEV" >&2
    if [[ -n "$RATE" ]]; then
      tc qdisc add dev "$DEV" root handle 1: netem "${netem_args[@]}"
      tc qdisc add dev "$DEV" parent 1:1 handle 10: tbf rate "$RATE" burst 32kbit latency 400ms
    else
      tc qdisc add dev "$DEV" root netem "${netem_args[@]}"
    fi
  fi

  if [[ -z "$TTL" ]]; then
    TTL=600
  fi
  if [[ "$TTL" != "0" ]]; then
    echo "auto-clear in ${TTL}s on $DEV"
    ( sleep "$TTL"; tc qdisc del dev "$DEV" root 2>/dev/null || true ) &>/dev/null &
  fi

  status_qdisc
}

case "$CMD" in
  apply) apply_qdisc ;;
  clear) need_root; clear_qdisc; status_qdisc ;;
  status) status_qdisc ;;
esac

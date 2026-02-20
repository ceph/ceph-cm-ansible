#!/usr/bin/env bash
 
set -euo pipefail

OUT="/etc/netplan/01-fog.yaml"
STAMP="/.cephlab_net_configured"
LOG="/var/log/netplan-from-link.log"

touch "$LOG"
chmod 0644 "$LOG"
exec > >(tee -a "$LOG") 2>&1

log() {
  echo "$(date -u +%FT%T.%N | cut -c1-23) netplan-from-link: $*" >&2
}

log "starting"
log "kernel=$(uname -r)"
log "cmdline=$(cat /proc/cmdline || true)"

rm -f /etc/netplan/*.yaml || true

pick_iface() {
  for d in /sys/class/net/*; do
    iface="$(basename "$d")"
    c="$d/carrier"

    case "$iface" in
      lo|docker*|veth*|virbr*|br*|cni*|flannel*|weave*|zt*|wg*|tun*|tap*|sit*|ip6tnl*|gre*|gretap*|erspan*|bond* )
        continue
        ;;
    esac

    ip link set dev "$iface" up 2>/dev/null || true
    v="$(cat "$c" 2>/dev/null || true)"
    log "probe iface=$iface carrier='${v}' path=$c"
    if [[ -r "$c" ]] && [[ "$v" == "1" ]]; then
      log "selected iface=$iface via carrier"
      echo "$iface"
      return 0
    fi
  done

  dflt="$(ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}' || true)"
  if [[ -n "${dflt:-}" ]]; then
    log "selected iface=$dflt via default-route"
    echo "$dflt"
    return 0
  fi

  return 1
}

iface=""
for i in $(seq 1 30); do
  iface="$(pick_iface || true)"
  if [[ -n "${iface:-}" ]]; then
    break
  fi
  log "no iface yet (attempt $i/30); sleeping 1s"
  sleep 1
done

if [[ -z "${iface:-}" ]]; then
  log "netplan-from-link could not find an uplink interface"
  log "ip -o link:"
  ip -o link show || true
  log "ip -4 addr:"
  ip -4 addr show || true
  log "ip -4 route:"
  ip -4 route show || true
  exit 0
fi

log "writing netplan to $OUT for iface=$iface"
cat >"$OUT" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${iface}:
      dhcp4: true
      dhcp6: false
      optional: false
      dhcp4-overrides:
        use-dns: true
        use-hostname: true
      nameservers:
        addresses: [10.20.192.11]
EOF

chmod 0600 "$OUT"

if command -v netplan >/dev/null 2>&1; then
  log "netplan generate"
  netplan generate || true
  log "netplan apply"
  netplan apply || true
else
  log "netplan not found; skipping generate/apply"
fi

log "final ip -4 addr for iface=$iface"
ip -4 addr show dev "$iface" || true

touch "$STAMP"
log "done; touched $STAMP"

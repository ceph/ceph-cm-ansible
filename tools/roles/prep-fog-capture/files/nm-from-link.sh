#!/usr/bin/env bash

set -euo pipefail

STAMP="/.cephlab_net_configured"
LOG="/var/log/nm-from-link.log"

touch "$LOG"
chmod 0644 "$LOG"
exec > >(tee -a "$LOG") 2>&1

log() {
  echo "$(date -u +%FT%T.%N | cut -c1-23) nm-from-link: $*" >&2
}

log "starting"

pick_iface() {
  for c in /sys/class/net/*/carrier; do
    iface="$(basename "$(dirname "$c")")"

    case "$iface" in
      lo|docker*|veth*|virbr*|br*|cni*|flannel*|weave*|zt*|wg*|tun*|tap*|sit*|ip6tnl*|gre*|gretap*|erspan*|bond* )
        continue
        ;;
    esac

    if [[ -r "$c" ]] && [[ "$(cat "$c")" == "1" ]]; then
      echo "$iface"
      return 0
    fi
  done

  ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}' || true
}

iface=""
for _ in $(seq 1 30); do
  iface="$(pick_iface || true)"
  if [[ -n "${iface:-}" ]]; then
    break
  fi
  sleep 1
done

if [[ -z "${iface:-}" ]]; then
  log "nm-from-link could not find an uplink interface" >&2
  exit 0
fi

systemctl enable --now NetworkManager || true

IFACE="$iface"
CONN="fog-dhcp-${IFACE}"

# Remove existing connections pinned to this interface (prevents stale MAC/IP settings)
nmcli -t -f NAME,DEVICE con show | awk -F: -v d="$IFACE" '$2==d {print $1}' | while read -r n; do
  [[ -n "$n" ]] && nmcli con delete "$n" || true
done

# Remove same-named conn if present
nmcli -t -f NAME con show | grep -qx "$CONN" && nmcli con delete "$CONN" || true

nmcli con add type ethernet ifname "$IFACE" con-name "$CONN" ipv4.method auto ipv6.method ignore
nmcli con mod "$CONN" connection.autoconnect yes
nmcli con mod "$CONN" ipv4.ignore-auto-dns yes
nmcli con mod "$CONN" ipv4.dns "10.20.192.11"
nmcli con up "$CONN" || true

touch "$STAMP"

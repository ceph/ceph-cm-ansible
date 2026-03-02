#!/usr/bin/env bash
# Wait for /.cephlab_net_configured, then set hostname + /etc/hostname + /etc/hosts
# Flow:
#   1) Wait for DHCP/global IPv4
#   2) Ping CHECK_HOST for up to 10 minutes (from any local IP)
#   3) Once ping works, try reverse DNS for up to 10 minutes (for an IP that can ping)
#   4) Set hostname and rewrite /etc/hostname + /etc/hosts
set -euo pipefail

# --- Config ---
CHECK_HOST="10.20.192.14"         # soko04 (must be reachable before we trust DNS)
DEFAULT_NAMESERVER="10.20.192.11" # override via env NAMESERVER or arg1

WAIT_FOR_FILE="/.cephlab_net_configured"
HOSTNAME_IS_SET_FILE="/.cephlab_hostname_set"
LOG="/var/log/cephlab-set-hostname.log"

NAMESERVER="${NAMESERVER:-${1:-${DEFAULT_NAMESERVER}}}"

MAX_WAIT_SECONDS="300"        # wait for /.cephlab_net_configured
PING_WINDOW_SECONDS="600"     # 10 minutes
DNS_WINDOW_SECONDS="600"      # 10 minutes
LOOP_SLEEP_SECONDS="2"

# --- Logging ---
touch "$LOG"
chmod 0644 "$LOG"
exec > >(tee -a "$LOG") 2>&1

log() {
  echo "$(date -u +%FT%T.%N | cut -c1-23) cephlab-set-hostname: $*" >&2
}

# --- Helpers ---
get_my_ips() {
  ip -4 -o addr show scope global 2>/dev/null \
    | awk '$2 != "docker0" {print $4}' \
    | cut -d/ -f1 \
    || true
}

# Reverse lookup helper (never non-zero; safe with set -euo pipefail)
reverse_lookup() {
  local ip="$1"
  local ns="$2"
  local name=""

  if command -v dig >/dev/null 2>&1; then
    name="$(dig +time=1 +tries=1 +short -x "${ip}" @"${ns}" 2>/dev/null | head -n1 | sed 's/\.$//' || true)"
  elif command -v host >/dev/null 2>&1; then
    name="$(host -W 1 "${ip}" "${ns}" 2>/dev/null | awk '/domain name pointer/ {print $5}' | sed 's/\.$//' | head -n1 || true)"
  elif command -v getent >/dev/null 2>&1; then
    name="$(getent hosts "${ip}" 2>/dev/null | awk '{print $2}' | head -n1 || true)"
  fi

  echo "${name}"
}

set_hostname() {
  local fqdn="$1"
  if command -v hostnamectl >/dev/null 2>&1; then
    hostnamectl set-hostname "${fqdn}"
  else
    hostname "${fqdn}"
  fi
}

can_ping_from_ip() {
  local src_ip="$1"
  # More tolerant per-attempt check but bounded:
  # 3 packets, 1s apart, wait up to 2s each; hard cap 10s.
  timeout 10s ping -I "${src_ip}" -nq -c3 -i 1 -W 2 "${CHECK_HOST}" >/dev/null 2>&1
}

# --- Main ---
if [[ -f "${HOSTNAME_IS_SET_FILE}" ]]; then
  log "We've already set the hostname before. Exiting..."
  exit 0
fi

log "Waiting for ${WAIT_FOR_FILE} (up to ${MAX_WAIT_SECONDS}s)..."
end=$((SECONDS + MAX_WAIT_SECONDS))
while [[ ! -f "${WAIT_FOR_FILE}" ]]; do
  if (( SECONDS >= end )); then
    log "Timed out waiting for ${WAIT_FOR_FILE}. Exiting."
    exit 1
  fi
  sleep 1
done
log "Flag file present. Proceeding."

# Wait for at least one global IPv4
myips="$(get_my_ips)"
if [[ -z "${myips}" ]]; then
  log "No non-loopback IPv4 addresses found yet. Will continue, but ping/DNS will likely fail until DHCP is up."
fi

# 1) Ping CHECK_HOST for up to 10 minutes (find a working source IP)
log "Checking connectivity to ${CHECK_HOST} for up to ${PING_WINDOW_SECONDS}s..."
ping_deadline=$((SECONDS + PING_WINDOW_SECONDS))
good_ip=""

while (( SECONDS < ping_deadline )); do
  myips="$(get_my_ips)"
  if [[ -z "${myips}" ]]; then
    log "No global IPv4 yet; waiting..."
    sleep "${LOOP_SLEEP_SECONDS}"
    continue
  fi

  for ip in ${myips}; do
    log "Pinging ${CHECK_HOST} from ${ip}..."
    if can_ping_from_ip "${ip}"; then
      good_ip="${ip}"
      log "Connectivity confirmed: ${ip} -> ${CHECK_HOST}"
      break
    fi
    log "Ping failed from ${ip}"
  done

  [[ -n "${good_ip}" ]] && break
  sleep "${LOOP_SLEEP_SECONDS}"
done

if [[ -z "${good_ip}" ]]; then
  log "Timed out (${PING_WINDOW_SECONDS}s) waiting for connectivity to ${CHECK_HOST}. Nothing changed."
  exit 1
fi

# 2) Now that we can reach CHECK_HOST, try reverse DNS for up to 10 minutes
log "Connectivity is good. Attempting reverse DNS via ${NAMESERVER} for up to ${DNS_WINDOW_SECONDS}s..."
dns_deadline=$((SECONDS + DNS_WINDOW_SECONDS))
newhostname=""

while (( SECONDS < dns_deadline )); do
  # Prefer the IP that proved connectivity; if it disappeared, re-find a good one.
  myips="$(get_my_ips)"
  if [[ -z "${myips}" ]]; then
    log "Lost all global-scope IPv4 addresses; waiting..."
    sleep "${LOOP_SLEEP_SECONDS}"
    continue
  fi

  if ! echo "${myips}" | tr ' ' '\n' | grep -qx "${good_ip}"; then
    log "Previously-good IP ${good_ip} is gone; re-checking connectivity..."
    good_ip=""
    for ip in ${myips}; do
      log "Pinging ${CHECK_HOST} from ${ip}..."
      if can_ping_from_ip "${ip}"; then
        good_ip="${ip}"
        log "Connectivity confirmed: ${ip} -> ${CHECK_HOST}"
        break
      fi
    done
    [[ -z "${good_ip}" ]] && { sleep "${LOOP_SLEEP_SECONDS}"; continue; }
  fi

  log "Reverse lookup for ${good_ip} via ${NAMESERVER}..."
  newhostname="$(reverse_lookup "${good_ip}" "${NAMESERVER}")"

  if [[ -n "${newhostname}" ]]; then
    log "Resolved ${good_ip} -> ${newhostname}"
    break
  fi

  log "Reverse lookup failed/empty for ${good_ip}"
  sleep "${LOOP_SLEEP_SECONDS}"
done

if [[ -z "${newhostname}" ]]; then
  log "Timed out (${DNS_WINDOW_SECONDS}s) waiting for reverse DNS via ${NAMESERVER}. Nothing changed."
  exit 1
fi

# Apply hostname + persist
set_hostname "${newhostname}"
shorthostname="${newhostname%%.*}"
echo "${newhostname}" > /etc/hostname

log "Rewriting /etc/hosts from scratch"
cat > /etc/hosts <<EOF
127.0.0.1 localhost
${good_ip} ${newhostname} ${shorthostname}

# IPv6
::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

log "Hostname updated: $(hostname); /etc/hostname and /etc/hosts rewritten."
touch "${HOSTNAME_IS_SET_FILE}"
exit 0

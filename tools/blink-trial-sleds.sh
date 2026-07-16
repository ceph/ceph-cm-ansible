#!/usr/bin/env bash
# Blink (or unblink) the locator LED on Supermicro Microcloud NVMe sleds
# via the BMC Redfish API using curl.
#
# Usage:
#   ./blink-trial-sleds.sh --user USER --password PASS --input-file list.csv
#   ./blink-trial-sleds.sh --user USER --password PASS trial007 [SERIAL ...]
#
# Input file format (one host per line, comments and blank lines ignored):
#   hostname,serial[,serial...]
#
# If a hostname is given with no serials, the script lists all drives it
# finds on that BMC (handy for discovering serial numbers).
#
# BMCs are reached at <short-hostname>.ipmi.sepia.ceph.com

set -uo pipefail

BMC_DOMAIN="ipmi.sepia.ceph.com"
CURL_OPTS=(-ksS --connect-timeout 10 --max-time 60)

usage() {
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-1}"
}

log()  { echo "$*"; }
err()  { echo "ERROR: $*" >&2; }

INPUT_FILE=""
BMC_USER=""
BMC_PASS=""
ACTION="on"   # on|off
HOST=""
CLI_SERIALS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input-file) INPUT_FILE="$2"; shift 2 ;;
        --user)       BMC_USER="$2";   shift 2 ;;
        --password)   BMC_PASS="$2";   shift 2 ;;
        --off)        ACTION="off";    shift ;;
        -h|--help)    usage 0 ;;
        -*)           err "Unknown option: $1"; usage ;;
        *)            if [[ -z "$HOST" ]]; then HOST="$1"; else CLI_SERIALS+=("$1"); fi; shift ;;
    esac
done

[[ -n "$BMC_USER" && -n "$BMC_PASS" ]] || { err "--user and --password are required"; usage; }
if [[ -n "$INPUT_FILE" && -n "$HOST" ]]; then
    err "Specify either --input-file or a hostname, not both"; usage
elif [[ -z "$INPUT_FILE" && -z "$HOST" ]]; then
    err "Specify --input-file or a hostname"; usage
fi
[[ -z "$INPUT_FILE" || -r "$INPUT_FILE" ]] || { err "Cannot read input file: $INPUT_FILE"; exit 1; }
command -v jq >/dev/null || { err "jq is required"; exit 1; }

FAILURES=0

rf_get() {  # rf_get BMC PATH
    curl "${CURL_OPTS[@]}" -u "$BMC_USER:$BMC_PASS" "https://$1$2" 2>/dev/null
}

rf_etag() {  # rf_etag BMC PATH -> ETag header value (may be empty)
    curl "${CURL_OPTS[@]}" -u "$BMC_USER:$BMC_PASS" -o /dev/null -D - "https://$1$2" 2>/dev/null |
        awk -F': ' 'tolower($1) == "etag" {print $2}' | tr -d '\r'
}

rf_patch() {  # rf_patch BMC PATH JSON -> echoes HTTP status code
    local etag hdrs=(-H "Content-Type: application/json")
    etag=$(rf_etag "$1" "$2")
    [[ -n "$etag" ]] && hdrs+=(-H "If-Match: $etag")
    curl "${CURL_OPTS[@]}" -u "$BMC_USER:$BMC_PASS" "${hdrs[@]}" \
        -X PATCH -d "$3" -o /dev/null -w '%{http_code}' "https://$1$2" 2>/dev/null
}

normalize() {  # uppercase, strip whitespace/quotes
    tr -d '[:space:]"' <<< "$1" | tr '[:lower:]' '[:upper:]'
}

drive_uris() {  # drive_uris BMC -> unique drive @odata.ids on stdout
    local bmc=$1 sys st ch
    {
        for sys in $(rf_get "$bmc" /redfish/v1/Systems | jq -r '.Members[]?."@odata.id"'); do
            for st in $(rf_get "$bmc" "$sys/Storage" | jq -r '.Members[]?."@odata.id"'); do
                rf_get "$bmc" "$st" | jq -r '.Drives[]?."@odata.id"'
            done
        done
        for ch in $(rf_get "$bmc" /redfish/v1/Chassis | jq -r '.Members[]?."@odata.id"'); do
            rf_get "$bmc" "$ch" | jq -r '.Links.Drives[]?."@odata.id"'
        done
    } 2>/dev/null | sort -u
}

set_led() {  # set_led BMC DRIVE_URI on|off -> 0 on success
    local bmc=$1 uri=$2 code payload
    local payloads
    if [[ $3 == on ]]; then
        payloads=('{"LocationIndicatorActive": true}' '{"IndicatorLED": "Blinking"}')
    else
        payloads=('{"LocationIndicatorActive": false}' '{"IndicatorLED": "Off"}')
    fi
    for payload in "${payloads[@]}"; do
        code=$(rf_patch "$bmc" "$uri" "$payload")
        [[ $code == 2* ]] && return 0
    done
    err "PATCH $uri failed (last HTTP status: ${code:-none})"
    return 1
}

process_host() {  # process_host HOSTNAME SERIAL...
    local host=$1; shift
    local serials=("$@")
    local bmc="${host%%.*}.$BMC_DOMAIN"
    local uris uri info dserial dname matched

    log "=== $host ($bmc) ==="
    uris=$(drive_uris "$bmc")
    if [[ -z "$uris" ]]; then
        err "$host: no drives found via Redfish (BMC unreachable or bad credentials?)"
        (( FAILURES++ ))
        return
    fi

    declare -A found=()   # normalized serial -> "uri|name"
    while read -r uri; do
        info=$(rf_get "$bmc" "$uri")
        dserial=$(jq -r '.SerialNumber // empty' <<< "$info")
        dname=$(jq -r '.Name // ."Id" // "unknown"' <<< "$info")
        [[ -n "$dserial" ]] && found[$(normalize "$dserial")]="$uri|$dname"
    done <<< "$uris"

    if [[ ${#serials[@]} -eq 0 ]]; then
        log "  No serials given; drives found on $host:"
        for dserial in "${!found[@]}"; do
            log "    $dserial  (${found[$dserial]#*|})"
        done
        return
    fi

    local want key
    for want in "${serials[@]}"; do
        want=$(normalize "$want")
        [[ -z "$want" ]] && continue
        matched=""
        for key in "${!found[@]}"; do
            if [[ "$key" == "$want" || "$key" == *"$want"* || "$want" == *"$key"* ]]; then
                matched=$key
                break
            fi
        done
        if [[ -z "$matched" ]]; then
            local avail="${!found[*]}"
            err "$host: no drive with serial $want (found: ${avail:-none})"
            (( FAILURES++ ))
            continue
        fi
        uri=${found[$matched]%%|*}
        if set_led "$bmc" "$uri" "$ACTION"; then
            log "  $matched: locator LED $ACTION (${found[$matched]#*|})"
        else
            err "$host: failed to set LED for $matched"
            (( FAILURES++ ))
        fi
    done
}

if [[ -n "$INPUT_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        [[ -z "${line//[[:space:],]/}" ]] && continue
        IFS=',' read -ra fields <<< "$line"
        host=$(tr -d '[:space:]"' <<< "${fields[0]}")
        [[ -z "$host" || "$host" =~ ^[Hh]ostname$ ]] && continue
        serials=()
        for f in "${fields[@]:1}"; do
            f=$(normalize "$f")
            [[ -n "$f" ]] && serials+=("$f")
        done
        if [[ ${#serials[@]} -eq 0 ]]; then
            log "=== $host: no serials listed, skipping ==="
            continue
        fi
        process_host "$host" "${serials[@]}"
    done < "$INPUT_FILE"
else
    process_host "$HOST" ${CLI_SERIALS[@]+"${CLI_SERIALS[@]}"}
fi

if (( FAILURES > 0 )); then
    err "$FAILURES failure(s)"
    exit 1
fi

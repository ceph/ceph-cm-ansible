#!/usr/bin/env bash
#
# Pending dnf updates as node_exporter textfile metrics, the dnf counterpart
# of apt_info.py. Counts `dnf check-update` lines per repo, once for every
# pending update and once for --security only (the one the Grafana alert
# reads), plus node_reboot_required from `dnf needs-restarting -r`.
# Modelled on yum.sh from prometheus-community/node-exporter-textfile-collector-scripts.

set -u -o pipefail

# count_by_repo METRIC HELP [dnf check-update flags...]
count_by_repo() {
  local metric=$1 help=$2 out rc counts
  shift 2
  out=$(dnf -q --setopt=autocheck_running_kernel=0 check-update "$@" 2>/dev/null)
  rc=$?
  # 0: nothing pending, 100: updates available, anything else: dnf failed
  if [[ $rc -ne 0 && $rc -ne 100 ]]; then
    echo "dnf check-update $* failed (exit $rc)" >&2
    return 1
  fi
  echo "# HELP ${metric} ${help}"
  echo "# TYPE ${metric} gauge"
  # "name.arch  version  repo" lines up to the Obsoleting Packages section,
  # whose continuation lines would otherwise be miscounted.
  counts=$(printf '%s\n' "${out}" | awk '
    /^Obsoleting Packages/ { exit }
    NF == 3 && $1 ~ /\./ { repo[$3]++ }
    END { for (r in repo) printf "%s %d\n", r, repo[r] }' | sort)
  if [[ -z ${counts} ]]; then
    echo "${metric}{repo=\"\"} 0"
  else
    while read -r repo n; do
      echo "${metric}{repo=\"${repo}\"} ${n}"
    done <<< "${counts}"
  fi
}

count_by_repo dnf_upgrades_pending "Dnf packages pending updates by repo." || exit 1
count_by_repo dnf_security_upgrades_pending "Dnf packages with pending security updates by repo." --security || exit 1

# needs-restarting lives in dnf-plugins-core; skip the metric when it is absent
# rather than report a reboot because dnf did not know the command.
if dnf needs-restarting --help > /dev/null 2>&1; then
  echo '# HELP node_reboot_required Node reboot is required for software updates.'
  echo '# TYPE node_reboot_required gauge'
  if dnf -q needs-restarting -r > /dev/null 2>&1; then
    echo 'node_reboot_required 0'
  else
    echo 'node_reboot_required 1'
  fi
fi

#!/usr/bin/env bash
# Stamp hostExitBios/hostExitEfi onto every FOG host of one machine type.
# Driven by the fog-server role's exit-types task; inputs arrive as
# environment variables:
#   FOG_MTYPE      machine-type prefix (hosts are named <type><NNN>)
#   FOG_EXIT_BIOS  bios exit method, or empty to leave it unmanaged
#   FOG_EXIT_EFI   efi exit method, or empty to leave it unmanaged
# Prints "CHANGED <n>" when rows were updated, "OK" otherwise.
set -euo pipefail

fs=/opt/fog/.fogsettings
U=$(sed -n "s/^snmysqluser='\(.*\)'/\1/p" "$fs")
P=$(sed -n "s/^snmysqlpass='\(.*\)'/\1/p" "$fs")
H=$(sed -n "s/^snmysqlhost='\(.*\)'/\1/p" "$fs"); H=${H:-localhost}
DB=$(sed -n "s/^mysqldbname='\(.*\)'/\1/p" "$fs"); DB=${DB:-fog}
myq(){ MYSQL_PWD="$P" mysql -N -h"$H" -u"$U" "$DB" -e "$1"; }

re="^${FOG_MTYPE}[0-9]+\$"
sets=()
diffs=()
if [ -n "${FOG_EXIT_BIOS:-}" ]; then
  sets+=("hostExitBios='$FOG_EXIT_BIOS'")
  diffs+=("NOT (hostExitBios <=> '$FOG_EXIT_BIOS')")
fi
if [ -n "${FOG_EXIT_EFI:-}" ]; then
  sets+=("hostExitEfi='$FOG_EXIT_EFI'")
  diffs+=("NOT (hostExitEfi <=> '$FOG_EXIT_EFI')")
fi
if [ ${#sets[@]} -eq 0 ]; then
  echo OK
  exit 0
fi
set_clause="${sets[0]}"; for s in "${sets[@]:1}"; do set_clause="$set_clause, $s"; done
diff_clause="${diffs[0]}"; for d in "${diffs[@]:1}"; do diff_clause="$diff_clause OR $d"; done

n=$(myq "SELECT COUNT(*) FROM hosts WHERE hostName REGEXP '$re' AND ($diff_clause);")
if [ "${n:-0}" -gt 0 ]; then
  myq "UPDATE hosts SET $set_clause WHERE hostName REGEXP '$re' AND ($diff_clause);"
  echo "CHANGED $n"
else
  echo OK
fi

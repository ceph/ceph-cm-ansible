#!/bin/bash
# Script to generate Cobbler credentials

tmpfile=$(mktemp)

# Basically `mkpasswd` but uses a small subset of special characters
password="$(
  { head -c 64 /dev/urandom | LC_ALL=C tr -dc '[:alnum:]' | head -c 1;
    head -c 256 /dev/urandom | LC_ALL=C tr -dc '[:alnum:]!@#$%&-' | head -c 11;
  } && echo
)"

if [ $# -eq 0 ]; then
  printf "Enter username: "
  read -r username
else
  username=$1
fi

cat << EOF

======== String for cobbler.yml ========
--- Cobbler v2 ---
$(echo -n "$username:Cobbler:" && echo -n "$username:Cobbler:$password" | md5sum | awk '{ print $1 }')

--- Cobbler v3 ---
$username:Cobbler:$(printf "$password" | openssl dgst -sha3-512 | awk '{ print $2 }')

======== E-mail to $username ========
Hi FIRSTNAME,

Here are your Cobbler user credentials.

Username: $username
Password: $password

Please do not share these credentials.

Thank you.

EOF

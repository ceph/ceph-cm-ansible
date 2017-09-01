#!/bin/bash
# Script to generate Cobbler credentials

tmpfile=$(mktemp)

# Basically `mkpasswd` but uses a small subset of special characters
password=$(head /dev/urandom | tr -dc 'A-Za-z0-9!@#$%&' | head -c 12 && echo)

if [ $# -eq 0 ]; then
  printf "Enter username: "
  read -r username
else
  username=$1
fi

cat << EOF

------ String for cobbler.yml ------
$(echo -n "$username:Cobbler:" && echo -n "$username:Cobbler:$password" | md5sum | awk '{ print $1 }')

------ E-mail to $username ------
Hi FIRSTNAME,

Here are your Cobbler user credentials.

Username: $username
Password: $password

Please do not share these credentials.

Thank you.

EOF

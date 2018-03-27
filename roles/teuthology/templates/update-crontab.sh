#/bin/bash
#
# {{ ansible_managed }}
#
# Script to update teuthology user's crontab for scheduling suite runs

REMOTE_CRONTAB_URL="{{ remote_crontab_url }}"
TEMP_DIR="$(mktemp -d /tmp/XXXXXXXX)"
CHKCRONTAB_PATH=~/bin/chkcrontab-venv

# Output remote crontab to temp file
curl -s -o $TEMP_DIR/new $REMOTE_CRONTAB_URL > /dev/null

# Output existing crontab
crontab -l > $TEMP_DIR/old

# Check for differences
diff $TEMP_DIR/old $TEMP_DIR/new

if [ $? -eq 0 ]; then
  echo "No changes.  Exiting."
  exit 0
fi

# Install chkcrontab if needed
# https://pypi.python.org/pypi/chkcrontab
if ! [ -x ${CHKCRONTAB_PATH}/bin/chkcrontab ]; then
  rm -rf $CHKCRONTAB_PATH
  mkdir $CHKCRONTAB_PATH
  virtualenv $CHKCRONTAB_PATH
  source $CHKCRONTAB_PATH/bin/activate
  pip install chkcrontab
else
  source $CHKCRONTAB_PATH/bin/activate
fi

# Perform the actual crontab syntax check
chkcrontab $TEMP_DIR/new

if [ $? -eq 0 ]; then
  # Install crontab
  deactivate
  crontab $TEMP_DIR/new
  rm -rf $TEMP_DIR
  echo "Installed new crontab successfully at $(date)"
else
  echo "Checking crontab in $TEMP_DIR/new failed"
  exit 1
fi

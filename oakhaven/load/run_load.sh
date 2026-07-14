#!/usr/bin/env bash
# Oakhaven load driver — Linux, contract v1.3.
# Windows equivalent (original machine, retained for reference): run_load.ps1
#
# Unlike the Windows version, this does NOT toggle local_infile itself:
# the `claude` user only has grants on oakhaven/oakhaven_silver/oakhaven_gold,
# not the SUPER/SYSTEM_VARIABLES_ADMIN privilege SET GLOBAL requires. Enable
# it once as root before running this script:
#   mysql -u root -p -e "SET GLOBAL local_infile = 1;"
#
# No credentials file (deliberately — see ubuntu_26.04 repo's MySQL setup):
# this prompts for the claude@localhost password interactively.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

current=$(mysql -u claude -h 127.0.0.1 -N -e "SHOW VARIABLES LIKE 'local_infile';" 2>/dev/null | awk '{print $2}' || true)
if [ "$current" != "ON" ]; then
  echo "local_infile is not ON. Run as root first:" >&2
  echo '  mysql -u root -p -e "SET GLOBAL local_infile = 1;"' >&2
  exit 1
fi

read -r -s -p "claude@localhost MySQL password: " MYSQL_PWD
echo
export MYSQL_PWD

mysql -u claude -h 127.0.0.1 --local-infile=1 --show-warnings < load_all.sql

unset MYSQL_PWD
echo "load complete"

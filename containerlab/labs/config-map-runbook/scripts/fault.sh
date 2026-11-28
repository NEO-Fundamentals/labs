#!/bin/bash
# The planted gap (Y has no return route to 10.29.1.0/24) is already in the stored configs and is applied at deploy.
# These two actions let you put the live gap back, or apply the live fix, without changing the stored files.
# Run it from the lab folder:  bash scripts/fault.sh <1|2>      The lab must be deployed.
#   1  put the planted gap back on y (delete the return route if it was added)
#   2  apply the live fix on y (add the return route); the stored config is not changed
cd "$(dirname "$0")/.." || exit 1
N=clab-config-map-runbook
docker exec $N-y true 2>/dev/null || { echo "the lab is not running: deploy it first"; exit 1; }
case "$1" in
  1) docker exec $N-y ip route del 10.29.1.0/24 >/dev/null 2>&1 || true ;;
  2) docker exec $N-y ip route replace 10.29.1.0/24 via 10.29.12.1 ;;
  *) echo "usage: bash scripts/fault.sh <1|2>"; exit 1 ;;
esac
echo "fault $1 is in place"

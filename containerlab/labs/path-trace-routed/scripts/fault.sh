#!/bin/bash
# Put one fault in place for an exercise (try the exercise before you read how the fault is made).
# Run it from the lab folder:  bash scripts/fault.sh <1|2>      The lab must be deployed. Reset the lab to undo all.
#   1  (exercise 4) a route disappears from one router
#   2  (exercise 5) a firewall change is loaded
cd "$(dirname "$0")/.." || exit 1
N=clab-path-trace-routed
docker exec $N-fw true 2>/dev/null || { echo "the lab is not running: deploy it first"; exit 1; }
case "$1" in
  1) docker exec $N-r2 vtysh -c 'configure terminal' -c 'no ip route 10.24.1.0/24 10.24.23.2' ;;
  2) docker exec -i $N-fw nft -f - < changes/fw-change.nft ;;
  *) echo "usage: bash scripts/fault.sh <1|2>"; exit 1 ;;
esac
echo "fault $1 is in place"

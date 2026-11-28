#!/bin/bash
# Put one fault in place for an exercise (try the exercise before you read how the fault is made).
# Run it from the lab folder:  bash scripts/fault.sh <1|2>      The lab must be deployed. Reset the lab to undo all.
#   1  (exercise 3) r1's host-side interface (eth2) is shut down
#   2  undo that (bring eth2 back up) — also used after exercise 3
cd "$(dirname "$0")/.." || exit 1
N=clab-monitoring-snmp-polling
docker exec $N-r1 true 2>/dev/null || { echo "the lab is not running: deploy it first"; exit 1; }
case "$1" in
  1) docker exec $N-r1 ip link set eth2 down ;;
  2) docker exec $N-r1 ip link set eth2 up ;;
  *) echo "usage: bash scripts/fault.sh <1|2>"; exit 1 ;;
esac
echo "fault $1 is in place"

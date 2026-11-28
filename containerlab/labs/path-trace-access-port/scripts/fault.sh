#!/bin/bash
# Put one fault in place for an exercise (try the exercise before you read how the fault is made).
# Run it from the lab folder:  bash scripts/fault.sh <1|2>      The lab must be deployed. Reset the lab to undo all.
#   1  (exercise 4) a switch port's setting is changed
#   2  (exercise 5) something happens to another switch port
N=clab-path-trace-access-port
docker exec $N-sw true 2>/dev/null || { echo "the lab is not running: deploy it first"; exit 1; }
case "$1" in
  1) docker exec $N-sw ip link set eth3 master vlan20 ;;
  2) docker exec $N-sw ip link set eth2 down ;;
  *) echo "usage: bash scripts/fault.sh <1|2>"; exit 1 ;;
esac
echo "fault $1 is in place"

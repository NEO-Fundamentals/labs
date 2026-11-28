#!/bin/bash
# Put one fault in place for an exercise (try the exercise before you read how the fault is made).
# Run it from the lab folder:  bash scripts/fault.sh <1|2|3>      The lab must be deployed. Reset the lab to undo all.
#   1  (exercise 3) host-b's access port is moved into the wrong VLAN
#   2  (exercise 4) r2 loses the return route to VLAN 10
#   3  (exercise 5) a firewall change is loaded
cd "$(dirname "$0")/.." || exit 1
N=clab-troubleshooting-capstone
docker exec $N-fw true 2>/dev/null || { echo "the lab is not running: deploy it first"; exit 1; }
case "$1" in
  1) docker exec $N-sw ip link set eth3 master vlan20 ;;
  2) docker exec $N-r2 ip route del 10.26.10.0/24 ;;
  3) docker exec -i $N-fw nft -f - < changes/fw-change.nft ;;
  *) echo "usage: bash scripts/fault.sh <1|2|3>"; exit 1 ;;
esac
echo "fault $1 is in place"

#!/bin/bash
# Put the controller-outage fault in place, or take it off.
# Run it from the lab folder:  bash scripts/fault.sh <1|2>      The lab must be deployed.
#   1  (exercise 5) cut the controller off at the edge (edge eth1 down)
#   2  bring the controller link back
cd "$(dirname "$0")/.." || exit 1
N=clab-cloud-managed-campus
docker exec $N-edge true 2>/dev/null || { echo "the lab is not running: deploy it first"; exit 1; }
case "$1" in
  1) docker exec $N-edge ip link set eth1 down ;;
  2) docker exec $N-edge ip link set eth1 up ;;
  *) echo "usage: bash scripts/fault.sh <1|2>"; exit 1 ;;
esac
echo "fault $1 is in place"

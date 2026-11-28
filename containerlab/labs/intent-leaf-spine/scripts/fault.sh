#!/bin/bash
# Put a drift fault in place (a hand change on leaf-1), or leave the student to redeploy the rendered file to undo it.
# Run it from the lab folder:  bash scripts/fault.sh 1      The lab must be deployed, and intent v1 must already be deployed.
#   1  (exercise 3) leaf-1's route to 10.31.10.64/26 goes via spine-1 only (one of the two ECMP next hops is dropped)
cd "$(dirname "$0")/.." || exit 1
N=clab-intent-leaf-spine
docker exec $N-leaf-1 true 2>/dev/null || { echo "the lab is not running: deploy it first"; exit 1; }
case "$1" in
  1) docker exec $N-leaf-1 ip route replace 10.31.10.64/26 via 10.31.0.0 ;;
  *) echo "usage: bash scripts/fault.sh 1"; exit 1 ;;
esac
echo "fault $1 is in place"

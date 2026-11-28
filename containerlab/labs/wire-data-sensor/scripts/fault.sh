#!/bin/bash
# Put one fault in place for an exercise (try the exercise before you read how the fault is made).
# Run it from the lab folder:  bash scripts/fault.sh <1|2>      The lab must be deployed. Reset the lab to undo all.
#   1  (exercise 3) the unknown host starts talking (GET /admin to the web server, every 2 seconds)
#   2  stop that traffic
cd "$(dirname "$0")/.." || exit 1
N=clab-wire-data-sensor
docker exec $N-unknown true 2>/dev/null || { echo "the lab is not running: deploy it first"; exit 1; }
case "$1" in
  1) docker exec -d $N-unknown python3 /neo/scripts/unknown.py
     sleep 1
     docker exec $N-unknown pgrep -af unknown.py >/dev/null || { echo "could not start the unknown host's traffic"; exit 1; }
     ;;
  2) docker exec $N-unknown sh -c 'pkill -f unknown.py || true' ;;
  *) echo "usage: bash scripts/fault.sh <1|2>"; exit 1 ;;
esac
echo "fault $1 is in place"

#!/bin/bash
# Put one fault in place for an exercise (try the exercise before you read how the fault is made).
# Run it from the lab folder:  bash scripts/fault.sh <1|2|3>      The lab must be deployed. Reset the lab to undo all.
#   1  (exercise 2) the application stops on every pool member
#   2  (exercise 3) the application on one member fails, its web server process keeps running
#   3  (exercise 4) a change to the load balancer's configuration is loaded
N=clab-load-balancer-troubleshooting
docker exec $N-lb true 2>/dev/null || { echo "the lab is not running: deploy it first"; exit 1; }
case "$1" in
  1) for s in web-1 web-2 web-3; do docker exec $N-$s pkill -f web_echo.py; done ;;
  2) docker exec $N-web-3 pkill -f web_echo.py; sleep 0.5
     docker exec -d $N-web-3 sh -c 'python3 -u /neo/scripts/web_echo.py web-3 --broken >>/var/log/web.log 2>&1' ;;
  3) docker exec $N-lb sh /neo/scripts/reload.sh /neo/changes/haproxy-change.cfg >/dev/null ;;
  *) echo "usage: bash scripts/fault.sh <1|2|3>"; exit 1 ;;
esac
echo "fault $1 is in place"

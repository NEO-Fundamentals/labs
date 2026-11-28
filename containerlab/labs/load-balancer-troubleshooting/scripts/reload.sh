#!/bin/sh
# Load an HAProxy configuration on lb, the careful way: check the file first, and only if it is valid stop the running
# HAProxy and start it again with the new file (the run-time changes made with hapctl.py are then forgotten).
# Usage on lb: sh /neo/scripts/reload.sh <config file>      (BIG-IP: "load sys config verify", then "load sys config")
CFG=${1:?usage: sh /neo/scripts/reload.sh <config file>}
haproxy -c -f "$CFG" || { echo "NOT loaded: $CFG has errors; HAProxy keeps running with the old configuration"; exit 1; }
# (-r S,R,D: count running HAProxy processes only; a stopped one stays listed as a zombie, because the container's first
#  process, "sleep infinity", never collects it. Zombies hold no port and do no work.)
if pgrep -x -r S,R,D haproxy >/dev/null; then
  pkill -x haproxy
  for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -x -r S,R,D haproxy >/dev/null || break; sleep 0.5; done
fi
# HAProxy writes its log to a pipe, and cat appends it to the file. (HAProxy switches its own output to non-blocking,
# which drops the "append" mode of a file opened with >>; a second HAProxy would then write over the start of the log.)
(haproxy -db -f "$CFG" 2>&1 | cat >>/var/log/haproxy.log) >/dev/null 2>&1 &
echo "loaded: $CFG"

#!/bin/bash
# Put sw3's priority back to 32768 (the default): sw1 is the root again.
# Run it from the lab folder:  bash changes/sw3-priority-undo.sh
N=clab-multivendor-stp-status
docker exec $N-sw3 ip link set br0 type bridge priority 32768 && echo "done: sw3-priority-undo"

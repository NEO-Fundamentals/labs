#!/bin/bash
# Put sw3 back to the default priority 32768: sw1 is the root again.
# Run it from the lab folder:  bash changes/sw3-priority-undo.sh
N=clab-spanning-tree-triangle
docker exec $N-sw3 ip link set br0 type bridge priority 32768 && echo "done: sw3-priority-undo"

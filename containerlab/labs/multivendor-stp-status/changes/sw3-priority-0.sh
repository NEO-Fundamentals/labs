#!/bin/bash
# Give sw3 (the Linux bridge) priority 0, lower than sw1's 4096: sw3 becomes the root of the whole tree.
# Run it from the lab folder:  bash changes/sw3-priority-0.sh
N=clab-multivendor-stp-status
docker exec $N-sw3 ip link set br0 type bridge priority 0 && echo "done: sw3-priority-0"

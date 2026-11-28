#!/bin/bash
# Give sw3 bridge priority 0, lower than sw1's 4096: sw3 wins the root election.
# Run it from the lab folder:  bash changes/sw3-priority-0.sh
N=clab-spanning-tree-triangle
docker exec $N-sw3 ip link set br0 type bridge priority 0 && echo "done: sw3-priority-0"

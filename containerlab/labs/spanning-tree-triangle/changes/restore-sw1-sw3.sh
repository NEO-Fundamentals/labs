#!/bin/bash
# Put the sw1 - sw3 link back.
# Run it from the lab folder:  bash changes/restore-sw1-sw3.sh
N=clab-spanning-tree-triangle
docker exec $N-sw1 ip link set eth2 up && echo "done: restore-sw1-sw3"

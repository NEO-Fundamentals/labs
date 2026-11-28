#!/bin/bash
# Cut the sw1 - sw3 link (sw1's end goes down, so sw3 loses its root port).
# Run it from the lab folder:  bash changes/cut-sw1-sw3.sh
N=clab-spanning-tree-triangle
docker exec $N-sw1 ip link set eth2 down && echo "done: cut-sw1-sw3"

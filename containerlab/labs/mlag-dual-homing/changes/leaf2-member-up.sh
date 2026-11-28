#!/bin/bash
# Put leaf2's member to h1 back up.
set -e
docker exec clab-mlag-dual-homing-leaf2 ip link set dev eth1 up

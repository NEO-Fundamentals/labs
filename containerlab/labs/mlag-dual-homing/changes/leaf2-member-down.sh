#!/bin/bash
# Lighter-lab equivalent of leaf2-member-down.cli: take leaf2's member to h1 down.
set -e
docker exec clab-mlag-dual-homing-leaf2 ip link set dev eth1 down

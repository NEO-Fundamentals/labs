#!/bin/bash
# Lighter-lab equivalent of leaf2-other-system-id.cli: leaf2 advertises a different LACP system ID.
set -e
docker exec clab-mlag-dual-homing-leaf2 sh -c 'echo 02:00:00:44:00:bb > /sys/class/net/bond0/bonding/ad_actor_system'

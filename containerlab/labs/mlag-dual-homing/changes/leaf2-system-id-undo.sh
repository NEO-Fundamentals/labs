#!/bin/bash
# Put leaf2's LACP system ID back to the same value as leaf1 (02:00:00:44:00:aa).
set -e
docker exec clab-mlag-dual-homing-leaf2 sh -c 'echo 02:00:00:44:00:aa > /sys/class/net/bond0/bonding/ad_actor_system'

#!/bin/bash
# Put the lighter-lab bond back to LACP (802.3ad), fast timers.
set -e
SW=clab-port-channel-lacp-sw2
docker exec "$SW" ip link set dev bond0 down
docker exec "$SW" ip link set dev bond0 type bond mode 802.3ad lacp_rate fast miimon 100
docker exec "$SW" ip link set dev bond0 up

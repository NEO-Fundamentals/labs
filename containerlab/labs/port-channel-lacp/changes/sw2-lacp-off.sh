#!/bin/bash
# Lighter-lab equivalent of sw2-lacp-off.cli: the bundle becomes a static bond and sends no LACPDUs.
set -e
SW=clab-port-channel-lacp-sw2
docker exec "$SW" ip link set dev bond0 down
docker exec "$SW" ip link set dev bond0 type bond mode balance-xor
docker exec "$SW" ip link set dev bond0 up

#!/bin/bash
# Lighter-lab equivalent of sw2-trunk-drop-30.cli: take VLAN 30 off the trunk.
set -e
SW=clab-vlans-trunks-sw2
docker exec "$SW" ip link set dev eth3.30 down
docker exec "$SW" ip link del eth3.30

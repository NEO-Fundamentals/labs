#!/bin/bash
# Put the lighter-lab trunk back: VLAN 10 native (untagged), VLAN 30 tagged.
set -e
SW=clab-vlans-trunks-sw2
docker exec "$SW" ip link set dev eth3 nomaster
docker exec "$SW" ip link set dev eth3 master br10
docker exec "$SW" ip link del eth3.10

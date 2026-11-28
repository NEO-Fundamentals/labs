#!/bin/bash
# Put VLAN 30 back on the lighter-lab trunk as a tagged VLAN.
set -e
SW=clab-vlans-trunks-sw2
docker exec "$SW" ip link add link eth3 name eth3.30 type vlan id 30
docker exec "$SW" ip link set dev eth3.30 master br30
docker exec "$SW" ip link set dev eth3.30 up

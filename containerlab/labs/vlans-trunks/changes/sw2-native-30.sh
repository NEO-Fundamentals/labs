#!/bin/bash
# Lighter-lab equivalent of sw2-native-30.cli: untagged trunk frames go to VLAN 30.
# VLAN 10 on the trunk becomes tagged (eth3.10).
set -e
SW=clab-vlans-trunks-sw2
docker exec "$SW" ip link add link eth3 name eth3.10 type vlan id 10
docker exec "$SW" ip link set dev eth3.10 master br10
docker exec "$SW" ip link set dev eth3.10 up
docker exec "$SW" ip link set dev eth3 nomaster
docker exec "$SW" ip link set dev eth3 master br30

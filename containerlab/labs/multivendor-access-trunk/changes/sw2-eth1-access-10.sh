#!/bin/bash
# sw2 (Linux bridge): make eth1 an ACCESS port in VLAN 10 instead of a trunk (the mode mismatch): VLAN 10 leaves untagged,
# VLAN 20 is not carried at all. sw1's end is still a trunk that expects every frame tagged.
# Run it from the lab folder:  bash changes/sw2-eth1-access-10.sh
N=clab-multivendor-access-trunk
docker exec $N-sw2 sh -c 'bridge vlan del dev eth1 vid 20; bridge vlan del dev eth1 vid 10; bridge vlan add dev eth1 vid 10 pvid untagged' \
  && echo "done: sw2-eth1-access-10"

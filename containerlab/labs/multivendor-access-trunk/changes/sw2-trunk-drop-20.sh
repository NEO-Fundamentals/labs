#!/bin/bash
# sw2 (Linux bridge): take VLAN 20 off the trunk port eth1. sw1 still sends VLAN 20 on its end of the trunk.
# Run it from the lab folder:  bash changes/sw2-trunk-drop-20.sh
N=clab-multivendor-access-trunk
docker exec $N-sw2 bridge vlan del dev eth1 vid 20 && echo "done: sw2-trunk-drop-20"

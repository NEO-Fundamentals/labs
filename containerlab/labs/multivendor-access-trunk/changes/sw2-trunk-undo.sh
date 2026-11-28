#!/bin/bash
# sw2 (Linux bridge): put VLAN 20 back on the trunk port eth1 (tagged).
# Run it from the lab folder:  bash changes/sw2-trunk-undo.sh
N=clab-multivendor-access-trunk
docker exec $N-sw2 bridge vlan add dev eth1 vid 20 && echo "done: sw2-trunk-undo"

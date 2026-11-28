#!/bin/bash
# sw2 (Linux bridge): make eth1 a trunk again: VLANs 10 and 20, tagged, no untagged VLAN.
# Run it from the lab folder:  bash changes/sw2-eth1-trunk.sh
N=clab-multivendor-access-trunk
docker exec $N-sw2 sh -c 'bridge vlan del dev eth1 vid 10; bridge vlan del dev eth1 vid 20 2>/dev/null; bridge vlan add dev eth1 vid 10; bridge vlan add dev eth1 vid 20' \
  && echo "done: sw2-eth1-trunk"

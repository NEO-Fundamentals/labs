#!/bin/bash
# Switch a lab fault on or off. Run it in a terminal on the VM (VS Code Terminal is fine), from the lab folder.
# Usage: bash scripts/faults.sh <drop|loss|mtu> <on|off>
#   drop  host-b silently discards packets for port 8080 (a filter in front of the server: no answer at all)
#   loss  host-b loses 25% of the packets it sends (real random packet loss from netem)
#   mtu   r1's link to host-b shrinks to MTU 600 and r1's "fragmentation needed" messages (ICMP type 3 code 4)
#         are dropped on the way to host-a (a path MTU black hole). Other ICMP, such as ping replies, still passes.
# The other faults need nothing switched on: port 8081 is closed (reset), port 8082 never reads (zero window),
# port 8083 resets in the middle of the transfer.
B=clab-wireshark-practice-host-b; R=clab-wireshark-practice-r1
case "$1 $2" in
  "drop on")  docker exec $B sh -c 'tc qdisc add dev eth1 ingress && tc filter add dev eth1 parent ffff: protocol ip u32 match ip dport 8080 0xffff action drop' ;;
  "drop off") docker exec $B tc qdisc del dev eth1 ingress ;;
  "loss on")  docker exec $B tc qdisc add dev eth1 root netem loss 25% ;;
  "loss off") docker exec $B tc qdisc del dev eth1 root ;;
  "mtu on")   docker exec $R sh -c 'ip link set eth2 mtu 600 && tc qdisc add dev eth1 root handle 1: prio && tc filter add dev eth1 parent 1: protocol ip prio 1 u32 match ip protocol 1 0xff match u8 3 0xff at 20 match u8 4 0xff at 21 action drop' ;;
  "mtu off")  docker exec $R sh -c 'tc qdisc del dev eth1 root; ip link set eth2 mtu 9500' ;;
  *) echo "usage: bash scripts/faults.sh <drop|loss|mtu> <on|off>"; exit 1 ;;
esac

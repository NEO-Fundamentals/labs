#!/bin/bash
# A broadcast storm for 2 seconds, then spanning tree back on. Run it from the lab folder:  bash changes/loop-2s.sh
# It turns STP off on all three switches and restarts each bridge, so every port forwards, sends ONE broadcast (an ARP question from h1),
# counts what h2 receives in 2 seconds, then turns STP back on. Without STP the triangle is a loop: the broadcast never dies.
N=clab-spanning-tree-triangle
rx() { docker exec $N-h2 cat /sys/class/net/eth1/statistics/rx_packets; }
for s in sw1 sw2 sw3; do
  # with STP off, restarting the bridge puts every port into forwarding (the kernel forgets the blocked port)
  docker exec $N-$s sh -c 'ip link set br0 type bridge stp_state 0; ip link set br0 down; ip link set br0 up'
done
echo "STP is off on sw1, sw2, sw3; every port forwards."
a=$(rx)
docker exec $N-h1 arping -c 1 -w 1 -I eth1 10.8.0.99 >/dev/null 2>&1 &
sleep 2
b=$(rx)
for s in sw1 sw2 sw3; do docker exec $N-$s ip link set br0 type bridge stp_state 1; done
echo "h2 received $((b - a)) frames in about 2 seconds, from one broadcast."
echo "STP is on again. The ports need about 10 seconds (listening, learning) before the network forwards again."
wait

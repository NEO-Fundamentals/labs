#!/bin/bash
# Lighter-lab sw2: a Linux bridge with classic 802.1D STP, matching the full lab's sw2
# (priority 32768, bridge MAC 02:00:00:36:00:02, short timers, cost 2000 on inter-switch ports).
set -e
ip link add br0 type bridge stp_state 1 priority 32768 hello_time 100 max_age 600 forward_delay 400
ip link set br0 address 02:00:00:36:00:02
for i in eth1 eth2 eth3; do
  ip link set dev "$i" master br0
done
for i in eth1 eth2; do
  bridge link set dev "$i" cost 2000
done
ip link set br0 up

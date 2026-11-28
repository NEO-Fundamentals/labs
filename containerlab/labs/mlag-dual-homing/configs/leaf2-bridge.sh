#!/bin/bash
# Lighter-lab leaf2: LACP bond toward h1 using the same system ID as leaf1 (02:00:00:44:00:aa),
# bridged to h3 (eth2) and the peer link (eth3). Needs the kernel bonding driver.
set -e
ip link add bond0 type bond mode 802.3ad lacp_rate fast miimon 100
# Same partner identity as leaf1's lag1, so h1 bundles both members.
if [ -f /sys/class/net/bond0/bonding/ad_actor_system ]; then
  echo 02:00:00:44:00:aa > /sys/class/net/bond0/bonding/ad_actor_system
fi
if [ -f /sys/class/net/bond0/bonding/ad_user_port_key ]; then
  echo 44 > /sys/class/net/bond0/bonding/ad_user_port_key
fi
ip link set dev eth1 down
ip link set dev eth1 master bond0
ip link add br0 type bridge
ip link set dev bond0 master br0
ip link set dev eth2 master br0
ip link set dev eth3 master br0
ip link set dev bond0 up
ip link set dev eth2 up
ip link set dev eth3 up
ip link set dev br0 up

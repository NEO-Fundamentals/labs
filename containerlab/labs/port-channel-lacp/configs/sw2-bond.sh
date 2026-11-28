#!/bin/bash
# Lighter-lab sw2: a two-member LACP bond (bond0) bridged to the host port (eth3).
# Needs the kernel bonding driver (present on the Ubuntu lab VM).
set -e
ip link add bond0 type bond mode 802.3ad lacp_rate fast miimon 100
ip link set dev eth1 down
ip link set dev eth2 down
ip link set dev eth1 master bond0
ip link set dev eth2 master bond0
ip link add br0 type bridge
ip link set dev bond0 master br0
ip link set dev eth3 master br0
ip link set dev bond0 up
ip link set dev eth3 up
ip link set dev br0 up

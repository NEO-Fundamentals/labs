#!/bin/bash
# Configure sw2 with one Linux bridge per VLAN (the same idea as path-trace-access-port).
# This works on kernels that do not support a VLAN-aware bridge (vlan_filtering).
# eth1 = access VLAN 10 (host-3), eth2 = access VLAN 30 (host-4),
# eth3 = trunk: VLAN 10 untagged (native) on br10, VLAN 30 tagged on eth3.30/br30.
set -e
# In case a leftover empty bridge exists from a failed start:
ip link del br0 2>/dev/null || true
ip link add name br10 type bridge
ip link add name br30 type bridge
ip link set dev br10 up
ip link set dev br30 up
ip link set dev eth1 master br10
ip link set dev eth1 up
ip link set dev eth2 master br30
ip link set dev eth2 up
ip link add link eth3 name eth3.30 type vlan id 30
ip link set dev eth3 master br10
ip link set dev eth3 up
ip link set dev eth3.30 master br30
ip link set dev eth3.30 up

#!/bin/bash
for i in 1 2 3 4 5 6 7 8 9 10; do
  ip link show eth1 >/dev/null 2>&1 && ip link show eth2 >/dev/null 2>&1 && ip link show eth3 >/dev/null 2>&1 && break
  sleep 1
done
ip route del default >/dev/null 2>&1 || true
ip link add br0 type bridge
ip link set eth2 master br0
ip link set eth3 master br0
ip link set br0 up
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up
ip addr add 10.30.3.1/24 dev eth1
ip addr add 10.30.1.1/24 dev br0
sysctl -q -w net.ipv4.ip_forward=1

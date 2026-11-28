#!/bin/bash
for i in 1 2 3 4 5 6 7 8 9 10; do
  ip link show eth1 >/dev/null 2>&1 && ip link show eth2 >/dev/null 2>&1 && break
  sleep 1
done
ip route del default >/dev/null 2>&1 || true
ip link set eth1 up
ip link set eth2 up
ip addr add 10.30.1.11/24 dev eth1
ip route add default via 10.30.1.1
sysctl -q -w net.ipv4.ip_forward=1
nohup python3 /neo/scripts/agent.py EAST-7F3K http://10.30.3.10:8080 >/var/log/agent.log 2>&1 &

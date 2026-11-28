#!/bin/bash
for i in 1 2 3 4 5 6 7 8 9 10; do
  ip link show eth1 >/dev/null 2>&1 && break
  sleep 1
done
ip route del default >/dev/null 2>&1 || true
ip addr add 10.30.3.10/24 dev eth1
ip route add default via 10.30.3.1
nohup python3 /neo/scripts/cloud.py serve >/var/log/cloud.log 2>&1 &

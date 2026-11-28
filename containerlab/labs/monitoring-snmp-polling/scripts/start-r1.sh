#!/bin/bash
# Wait until the lab interfaces exist, then address them and start snmpd.
for i in 1 2 3 4 5 6 7 8 9 10; do
  ip addr add 10.27.1.1/24 dev eth1 && break
  sleep 1
done
for i in 1 2 3 4 5 6 7 8 9 10; do
  ip addr add 10.27.2.1/24 dev eth2 && break
  sleep 1
done
sysctl -q -w net.ipv4.ip_forward=1
snmpd -C -c /neo/configs/snmpd.conf

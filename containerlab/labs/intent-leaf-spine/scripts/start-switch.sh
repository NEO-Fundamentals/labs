#!/bin/bash
# Spines and leaves: wait for the fabric links, drop the management default route, turn forwarding on.
# Addresses and routes come later, from fabric.py deploy.
for i in 1 2 3 4 5 6 7 8 9 10; do
  ip link show dev lo >/dev/null 2>&1 && break
  sleep 1
done
# Bring any already-present lab links up; containerlab sets them up, but be safe.
for n in $(ip -o link show | awk -F': ' '{print $2}' | cut -d@ -f1); do
  case "$n" in lo|eth0) continue ;; esac
  ip link set "$n" up >/dev/null 2>&1 || true
done
ip route del default >/dev/null 2>&1 || true
sysctl -q -w net.ipv4.ip_forward=1
sysctl -q -w net.ipv4.conf.all.rp_filter=0
sysctl -q -w net.ipv4.conf.default.rp_filter=0

#!/bin/bash
# Wait until the lab interfaces exist, drop the management default route, apply this node's stored config, then
# (on x and y) turn forwarding on. On web, start the web server.
set -u
dev=$1
for i in 1 2 3 4 5 6 7 8 9 10; do
  ip link show eth1 >/dev/null 2>&1 && break
  sleep 1
done
ip route del default >/dev/null 2>&1 || true
ip -batch /neo/configs/${dev}.conf
if [ "$dev" = x ] || [ "$dev" = y ]; then
  sysctl -q -w net.ipv4.ip_forward=1
  sysctl -q -w net.ipv4.conf.all.rp_filter=0
  sysctl -q -w net.ipv4.conf.default.rp_filter=0
  sysctl -q -w net.ipv4.conf.eth1.rp_filter=0
  sysctl -q -w net.ipv4.conf.eth2.rp_filter=0
fi
if [ "$dev" = web ]; then
  mkdir -p /srv/www
  echo "hello from web (10.29.2.20)" > /srv/www/index.html
  echo "10.29.2.20 $(hostname)" >> /etc/hosts
  nohup python3 -m http.server 80 --bind 10.29.2.20 --directory /srv/www >/var/log/web.log 2>&1 &
  for i in 1 2 3 4 5 6 7 8 9 10; do
    ss -ltn | grep -q "10.29.2.20:80" && break
    sleep 1
  done
fi

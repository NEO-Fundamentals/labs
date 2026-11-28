#!/bin/bash
for i in 1 2 3 4 5 6 7 8 9 10; do
  ip link show eth1 >/dev/null 2>&1 && break
  sleep 1
done
ip route del default >/dev/null 2>&1 || true
ip addr add 10.30.10.130/25 dev eth1
ip route add default via 10.30.10.129
mkdir -p /srv/www
echo "hello from web (10.30.10.130)" > /srv/www/index.html
echo "10.30.10.130 $(hostname)" >> /etc/hosts
nohup python3 -m http.server 80 --bind 10.30.10.130 --directory /srv/www >/var/log/web.log 2>&1 &
for i in 1 2 3 4 5 6 7 8 9 10; do
  ss -ltn | grep -q "10.30.10.130:80" && break
  sleep 1
done

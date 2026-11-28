#!/bin/bash
for i in 1 2 3 4 5 6 7 8 9 10; do
  ip link show eth1 >/dev/null 2>&1 && break
  sleep 1
done
ip route del default >/dev/null 2>&1 || true
ip addr add 10.31.10.74/26 dev eth1 >/dev/null 2>&1 || true
ip route replace default via 10.31.10.65
mkdir -p /srv/www
echo "hello from host-b (10.31.10.74)" > /srv/www/index.html
# http.server looks up its own hostname at start; without a hosts entry it can sit for many seconds before it binds.
echo "10.31.10.74 $(hostname)" >> /etc/hosts
nohup python3 -m http.server 80 --bind 10.31.10.74 --directory /srv/www >/var/log/web.log 2>&1 &
for i in 1 2 3 4 5 6 7 8 9 10; do
  ss -ltn | grep -q "10.31.10.74:80" && break
  sleep 1
done

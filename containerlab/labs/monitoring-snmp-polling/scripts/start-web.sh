#!/bin/bash
# Wait until eth1 exists (it can appear a second after the container starts), then address it and start the web server.
for i in 1 2 3 4 5 6 7 8 9 10; do
  ip addr add 10.27.2.20/24 dev eth1 && break
  sleep 1
done
ip route replace default via 10.27.2.1
echo "hello from web (10.27.2.20)" > /srv/www/index.html
head -c 200000 /dev/zero > /srv/www/big.bin
echo "10.27.2.20 host-web" >> /etc/hosts
nohup python3 -m http.server 80 --bind 10.27.2.20 --directory /srv/www >/var/log/web.log 2>&1 &

#!/bin/bash
for i in 1 2 3 4 5 6 7 8 9 10; do
  ip addr add 10.27.1.10/24 dev eth1 && break
  sleep 1
done
ip route replace default via 10.27.1.1

#!/bin/bash
# Put sw2's link to sw3 back up.
set -e
docker exec clab-multivendor-stp-status-sw2 ip link set dev eth2 up

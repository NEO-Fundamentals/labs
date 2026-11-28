#!/bin/bash
# Lighter-lab equivalent of sw2-cut-to-sw3.cli: take sw2's link to sw3 down.
set -e
docker exec clab-multivendor-stp-status-sw2 ip link set dev eth2 down

#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed and BGP established (wait a minute after Deploy).
# Writes ../captures/*.pcapng. Run it from the lab folder:  bash scripts/make-captures.sh
cd "$(dirname "$0")/.." || exit 1
L=ebgp-two-sites; N=clab-$L; mkdir -p captures
containerlab capture --name $L --target edge-b:eth1 --duration 14s -w captures/ebgp-session-restart.pcapng >/dev/null 2>&1 &
sleep 4
docker exec $N-edge-b vtysh -c "clear bgp ipv4 unicast 10.0.12.1"
wait
ls -l captures

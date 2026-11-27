#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed and BGP established (wait a minute after Deploy).
# Writes ../captures/*.pcapng. Run it from the lab folder:  bash scripts/make-captures.sh
cd "$(dirname "$0")/.." || exit 1
L=bgp-ebgp-ibgp-path-choice; N=clab-$L; mkdir -p captures
cap() {  # cap <file> <node:interface> : record 14 s in the background, then give it 4 s to start
  containerlab capture --name $L --target "$2" --duration 14s -w "captures/$1.pcapng" >/dev/null 2>&1 &
  sleep 4
}
cap ibgp-session-restart edge-b1:eth2
docker exec $N-edge-b1 vtysh -c "clear bgp ipv4 unicast 10.0.23.2"; wait
cap ebgp-session-restart edge-b1:eth1
docker exec $N-edge-b1 vtysh -c "clear bgp ipv4 unicast 10.0.12.1"; wait
ls -l captures

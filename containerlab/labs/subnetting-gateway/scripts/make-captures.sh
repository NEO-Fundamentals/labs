#!/bin/bash
# Re-record this lab's sample captures from host-a's cable. The lab must be deployed. Run from the lab folder:
#   bash scripts/make-captures.sh        (no password needed)
cd "$(dirname "$0")/.." || exit 1
L=subnetting-gateway; A=clab-$L-host-a; mkdir -p captures
cap() { containerlab capture --name $L --target host-a:eth1 --duration "$2" -w "captures/$1.pcapng" >/dev/null 2>&1 & sleep 2; }
# FRR applies r1's addresses 10 to 20 s after deploy: wait until r1 has both gateway addresses
until docker exec clab-$L-r1 ip -br addr | grep -q 10.0.2.129/26 && docker exec clab-$L-r1 ip -br addr | grep -q 10.0.2.65/26; do sleep 2; done
# clear host-a's ARP cache so the capture shows the ARP requests
docker exec $A ip neigh flush all
cap subnet-same-and-other 8s
docker exec $A ping -c 2 -W 1 10.0.2.190     # same /26: ARP for the host itself
docker exec $A ping -c 2 -W 1 10.0.2.66      # other /26: ARP for the gateway .129, router forwards
wait
ls -l captures

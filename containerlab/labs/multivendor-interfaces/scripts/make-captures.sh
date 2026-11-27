#!/bin/bash
# Re-record this lab's sample capture from l's eth1 cable. The lab must be deployed. Run from the lab folder:
#   bash scripts/make-captures.sh        (no password needed)
cd "$(dirname "$0")/.." || exit 1
L=multivendor-interfaces; N=clab-$L; mkdir -p captures
cap() { containerlab capture --name $L --target l:eth1 --duration "$2" -w "captures/$1.pcapng" >/dev/null 2>&1 & sleep 2; }
# FRR applies its startup file a few seconds after deploy: wait until L has its address
ok=; for i in $(seq 45); do docker exec $N-l ip -br addr show eth1 2>/dev/null | grep -q "10\.0\.2\.1/30" && { ok=1; break; }; sleep 2; done   # waits at most 90 s
[ -n "$ok" ] || { echo "L has no address on eth1 after 90 seconds. Is the lab deployed (containerlab inspect --all)?"; exit 1; }
# Works: ping across the /30
cap interfaces-ping-ok 6s;       docker exec $N-l ping -c 3 -W 1 10.0.2.2; wait
# Typo: R moves to 10.0.2.6/30, so L cannot reach 10.0.2.2 (ARP requests go unanswered)
docker exec -i $N-r vtysh < changes/r-typo.txt >/dev/null
docker exec $N-l ip neigh flush all   # forget R's old hardware address so the ARP requests show
cap interfaces-ping-typo 10s;    docker exec $N-l ping -c 3 -W 1 10.0.2.2; wait
docker exec -i $N-r vtysh < changes/r-fix.txt >/dev/null
ls -l captures

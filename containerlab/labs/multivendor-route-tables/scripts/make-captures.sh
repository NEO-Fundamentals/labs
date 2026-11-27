#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. Writes ../captures/*.pcapng.
# Run it from the lab folder:  bash scripts/make-captures.sh   (no password needed; about one minute)
cd "$(dirname "$0")/.." || exit 1
L=multivendor-route-tables; N=clab-$L; mkdir -p captures
cap() {  # cap <file> <node:interface> <seconds>: record in the background, then give it 4 s to start
  containerlab capture --name $L --target "$2" --duration "$3" -w "captures/$1.pcapng" >/dev/null 2>&1 &
  sleep 4
}
# FRR loads the static routes 10-20 s after deploy: wait until r1 has the /25
ok=; for i in $(seq 45); do docker exec $N-r1 ip route show 10.100.0.128/25 2>/dev/null | grep -q via && { ok=1; break; }; sleep 2; done   # waits at most 90 s
[ -n "$ok" ] || { echo "r1 has no 10.100.0.128/25 route after 90 seconds. Is the lab deployed (containerlab inspect --all)?"; exit 1; }
# 1: the /25 wins. The capture starts first; then r1 forgets its neighbours and pings 10.100.0.130; the packets leave on eth2 toward r3.
cap routes-longest-match-r3 r1:eth2 8s; docker exec $N-r1 ip neigh flush all; docker exec $N-r1 ping -c 3 10.100.0.130; wait
# 2: eth2 shut down. The /25 now resolves through the default route to r2, which has no route and answers
#    "Destination Net Unreachable". Recorded on eth1, the cable to r2.
docker exec -i $N-r1 vtysh < changes/r1-shutdown-eth2.txt; sleep 2
cap routes-eth2-down-unreachable r1:eth1 8s; docker exec $N-r1 ping -c 3 -W 1 10.100.0.130; wait
docker exec -i $N-r1 vtysh < changes/r1-no-shutdown-eth2.txt
command -v editcap >/dev/null && for f in captures/*.pcapng; do editcap -F pcapng -s 200 "$f" "$f.tmp" && mv "$f.tmp" "$f"; done
ls -l captures

#!/bin/bash
# Re-record this lab's sample captures. The lab must be deployed. Writes ../captures/*.pcapng.
# Run it from the lab folder:  bash scripts/make-captures.sh   (no password needed; about one minute)
cd "$(dirname "$0")/.." || exit 1
L=routing-table-next-hop; N=clab-$L; mkdir -p captures
cap() {  # cap <file> <node:interface> <seconds>: record in the background, then give it 4 s to start
  containerlab capture --name $L --target "$2" --duration "$3" -w "captures/$1.pcapng" >/dev/null 2>&1 &
  sleep 4
}
# Wait until the path works end to end: r1 (FRR) loads its routes 10-20 s after deploy, r2 (SR Linux) needs 1-2 min
ok=; for i in $(seq 120); do docker exec $N-host-1 ping -c 1 -W 1 10.2.2.10 >/dev/null 2>&1 && { ok=1; break; }; sleep 3; done   # waits at most 6 minutes
[ -n "$ok" ] || { echo "host-1 cannot reach host-2 after 6 minutes. Is the lab deployed (containerlab inspect --all)? Is r2 (SR Linux) running?"; exit 1; }
# 1: host-1's first hop. The capture starts first; then host-1 forgets r1's hardware address, ARPs for its gateway and pings host-2.
cap nexthop-hop1-host1 host-1:eth1 8s; docker exec $N-host-1 ip neigh flush all; docker exec $N-host-1 ping -c 3 10.2.2.10; wait
# 2: the second hop. The capture starts first; then r1 forgets r2's hardware address and ARPs for the next hop 10.0.12.2 (not for host-2).
cap nexthop-hop2-transit r1:eth2 8s; docker exec $N-r1 ip neigh flush dev eth2; docker exec $N-host-1 ping -c 3 10.2.2.10; wait
# 3: the wrong /32 host route. Packets for 10.2.2.10 now leave r1 toward sink and never come back.
docker exec -i $N-r1 vtysh < changes/r1-add-host-route.txt; sleep 2
cap nexthop-hostroute-sink r1:eth3 8s; docker exec $N-host-1 ping -c 3 -W 1 10.2.2.10; wait
docker exec -i $N-r1 vtysh < changes/r1-remove-host-route.txt
command -v editcap >/dev/null && for f in captures/*.pcapng; do editcap -F pcapng -s 200 "$f" "$f.tmp" && mv "$f.tmp" "$f"; done
ls -l captures
